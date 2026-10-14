#!/usr/bin/env bash

#if more than one argument is provided, print usage and exit with code 1
if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [repo_path]"
    exit 1
fi

#if one argument is provided (the repo path), change into that directory
if [ "$#" -eq 1 ]; then
    #change directory or exit immediately if the directory doesn't exist
    cd "$1" || exit 1
fi

#check if the current directory is a valid git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not a Git repository!"
    exit 1
fi

while true; do
    echo "1. Validate and Archive Branches"
    echo "2. Integrate Feature Branches"
    echo "3. Enforce Branch Hygiene"
    echo "4. Sync Report and Safe Rewrite"
    echo "5. Exit"

    read -p "Choose an option: " choice

    case $choice in
    1)  
        echo "--- Validate and Archive Branches ---"
        branch_list=$(git for-each-ref --format='%(refname:short)' refs/heads/) #ignore main and branches feature/, bugfix/, hotfix/ or archive/

        for branch in $branch_list; do
            case "$branch" in
                    main|feature/*|bugfix/*|hotfix/*|archive/*)
                        continue
                        ;;
                    *)
                        new_name="archive/$branch" #rename other branches

                        if git branch -m "$branch" "$new_name" 2>/dev/null; then
                            
                            commit_date=$(git log -1 --format=%cs "$new_name")

                            #archive tag pointing to the new branch name
                            git tag "archived-$branch-$commit_date" "$new_name"
                        
                            #how many commits this branch is ahead of main
                            commit_count=$(git rev-list --count main.."$new_name")
                            
                            #if it has more than 5 commits - add a milestone tag
                            if [ "$commit_count" -gt 5 ]; then
                                git tag "milestone-$branch-$commit_count" "$new_name"
                                echo "Renamed $branch to $new_name and added archived and milestone tags."
                            else
                                echo "Renamed $branch to $new_name and added archived tag."
                            fi
                            
                        else
                            echo "Skipped $branch: could not rename to $new_name."
                        fi
                        ;;
            esac
        done
        echo "-----------------------------------------"
            ;;
    
    2)
        echo "--- Integrate Feature Branches ---"

        #abort operation if there are uncommitted changes in the working tree
        if ! git diff-index --quiet HEAD --; then
            echo "Cannot run: working tree has uncommitted changes."
            continue
        fi

        #remember the starting branch to restore it later
        current_branch=$(git branch --show-current)

        branch_list=$(git for-each-ref --format='%(refname:short)' refs/heads/)
            
        for branch in $branch_list; do
            case "$branch" in
                feature/*)
                    #commits ahead of main
                    commit_count=$(git rev-list --count main.."$branch")
                        
                    #skip if the feature branch has no new commits
                    if [ "$commit_count" -eq 0 ]; then
                        echo "$branch: nothing to integrate"
                        continue
                    fi
                        
                    #check if a fast-forward merge is possible
                    if git merge-base --is-ancestor main "$branch"; then
                        read -p "Fast-forward $branch? (Y/N): " answer
                        if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
                            git switch main
                            git merge --ff-only "$branch"
                            echo "Fast-forwarded $branch into main."
                        else
                            echo "Skipped $branch."
                        fi
                    #if not fast-forward, check conflicts and do --squash
                    elif git merge-tree --write-tree main "$branch" > /dev/null; then
                        read -p "Squash merge $branch? (Y/N): " answer
                        if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
                            git switch main
                            git merge --squash "$branch"
                            git commit -m "Squashed $branch"
                            git branch -D "$branch"
                            echo "Squashed and deleted $branch."
                        else
                            echo "Skipped $branch."
                        fi
                    else
                        echo "$branch conflicts with main."
                    fi
                    ;;
                *)
                    #ignore all not feature branches
                    continue
                    ;;
            esac
        done
        #restore the original branch, fallback to main if the original was deleted
        if git show-ref --verify --quiet "refs/heads/$current_branch"; then
            git switch "$current_branch"
        else
            git switch main
        fi
        echo "----------------------------------"
        ;;

    3)
        echo "--- Enforce Branch Hygiene ---"
        if ! git diff-index --quiet HEAD --; then
            echo "Cannot run: working tree has uncommitted changes."
            continue
        fi
        current_branch=$(git branch --show-current)

        branch_list=$(git for-each-ref --format='%(refname:short)' refs/heads/)
        #Regex for version suffix like -v1, -v23, -v2.3, -v1.15
        regex=".*-v[0-9]+(\.[0-9]+)*$"
        
        for branch in $branch_list; do
            case "$branch" in
                main|feature/*|bugfix/*|hotfix/*|archive/*)
                    continue
                    ;;
                *)
                    #if branch doesn't end with a version suffix, rename it to archive/<original-name>.
                    if [[ ! "$branch" =~ $regex ]]; then
                        new_name="archive/$branch"
                        
                        if git branch -m "$branch" "$new_name"; then
                            commit_date=$(git log -1 --format=%cs "$new_name")

                            #tag the original state before squashing
                            git tag "archived-$branch-$commit_date" "$new_name"
                            
                            commit_count=$(git rev-list --count main.."$new_name")
                            if [ "$commit_count" -gt 5 ]; then
                                git tag "milestone-$branch-$commit_count" "$new_name"
                            fi
                            
                            #ask to squash entire history into a single root commit
                            read -p "Squash $new_name history into a single commit? (Y/N): " answer
                            if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
                                git switch "$new_name"
                                #the very first commit of the branch
                                root_commit=$(git rev-list --max-parents=0 HEAD)
                                #--soft reset keeps all file changes staged
                                git reset --soft "$root_commit"
                                git commit --amend --allow-empty -m "Squashed archive of $branch"
                                git switch main
                                echo "Archived $branch to $new_name, added tags, and squashed history."
                            else
                                echo "Archived $branch to $new_name and added tags."
                            fi
                        else
                            echo "Error: could not rename $branch"
                        fi
                    else
                        echo "$branch matches version suffix, keeping."
                    fi
                    ;;
            esac
        done
        #return to the starting branch, checking if it was renamed to archive/
        if git show-ref --verify --quiet "refs/heads/archive/$current_branch"; then
            git switch "archive/$current_branch"
        elif git show-ref --verify --quiet "refs/heads/$current_branch"; then
            git switch "$current_branch"
        else
            git switch main
        fi
        echo "------------------------------"
        ;;

    4)
        echo "--- Sync Report and Safe Rewrite ---"
        if ! git diff-index --quiet HEAD --; then
            echo "Cannot run: working tree has uncommitted changes."
            continue
        fi
        current_branch=$(git branch --show-current)
        
        branch_list=$(git for-each-ref --format='%(refname:short)' refs/heads/)
        for branch in $branch_list; do
            case "$branch" in
                feature/*)
                    #get ahead and behind commit counts to main
                    counts=$(git rev-list --left-right --count main..."$branch")
                    #split the output into two variables
                    read behind ahead <<< "$counts"
                    #the common ancestor commit
                    old_base=$(git merge-base main "$branch")
                    
                    echo "Branch: $branch | Merge base: $(git rev-parse --short "$old_base") | Behind: $behind | Ahead: $ahead"
                    
                    #if behind = 0, the branch is already based on the latest main
                    if [ "$behind" -eq 0 ]; then
                        echo "$branch is up to date."
                        continue
                    fi
                    
                    read -p "Rebase $branch onto main? (Y/N): " answer
                    if [[ "$answer" == "Y" || "$answer" == "y" ]]; then
                        commit_date=$(git log -1 --format=%cs "$branch")
                        tag_name="backup-$branch-$commit_date"
                        
                        #check if a backup tag already exists
                        if git show-ref --verify --quiet "refs/tags/$tag_name"; then
                            #get the commit hashes that the tag and the branch point to
                            tag_hash=$(git rev-parse "$tag_name^{commit}")
                            branch_hash=$(git rev-parse "$branch")
                            
                            #if hashes differ, abort the rewrite to prevent data loss
                            if [[ "$tag_hash" != "$branch_hash" ]]; then
                                echo "Backup tag exists and points to a different commit. Skipping $branch - no rewrite without a backup."
                                continue
                            else
                                echo "Backup tag $tag_name already exists and points to the branch tip. Keeping it."
                            fi
                        else
                            #create a new backup tag
                            git tag "$tag_name" "$branch"
                            echo "Created backup tag $tag_name."
                        fi
                        
                        #try rebase
                        git switch "$branch"
                        if git rebase main > /dev/null 2>&1; then
                            echo "Rebase successful."
                            
                            #compare commits before and after the rebase using the old merge base and backup tag
                            diff_output=$(git range-diff "$old_base".."$tag_name" main.."$branch")
                            #filter lines to find any that lack the '=' (indicating a change)
                            changed_lines=$(echo "$diff_output" | grep -v "=")
                            
                            #if no changed lines exist, all commits were perfectly preserved
                            if [ -z "$changed_lines" ]; then
                                echo "Verdict: all $ahead commits preserved."
                            else
                                echo "Verdict: changed — review:"
                                echo "$changed_lines"
                            fi
                        else
                            #if rebase fails, abort to return to the clean state
                            git rebase --abort
                            echo "$branch needs manual rebase. Backup tag stays."
                        fi
                    else
                        echo "Skipped rebase for $branch."
                    fi
                    ;;
                *)
                    continue
                    ;;
            esac
        done
        
        #restore the original branch
        if git show-ref --verify --quiet "refs/heads/$current_branch"; then
            git switch "$current_branch"
        else
            git switch main
        fi
        echo "------------------------------------"
        ;;

    5)
        #exit the script with a success code 0
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        #catch invalid menu inputs
        echo "Invalid option. Please choose 1-5."
        ;;
    esac
done
