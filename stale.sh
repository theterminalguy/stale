#!/bin/sh

# This script is used to list remote git branches that have been 
# merged into develop but not into main or the release branch.

remove_stale_branches() {
	echo "Fetching remote branches..."

	# run `git fetch` to get the latest remote branches
	git fetch

	# if `git fetch` fails, exit the script
	if [ $? -ne 0 ]; then
		echo "git fetch failed"
		exit 1
	fi

	# get the remote origin name
	origin=$(git remote -v | grep fetch | awk '{print $1}')

	# get the branch names and store them in an array. Ignore the main and any branch starting with release.
	branches=($(git branch -r | grep -v main | grep -v develop | grep -v release | grep -v HEAD | sed "s/$origin\///"))

	# get all release branches
	release_branches=($(git branch -r | grep release | sed "s/$origin\///"))

	# create an empty array to store the stale branches
	stale_branches=()

	for branch in ${branches[@]}; do
		# if branch has been merged into main, skip it
		if git branch -r --merged "$origin/main" | grep -q "$branch"; then
			echo "Skipping $branch because it has been merged into main"
			continue
		fi

		# loop through the release branches and check if the branch has been merged into any of them
		for release_branch in ${release_branches[@]}; do
			# if branch has been merged into release branch, skip it
			if git branch -r --merged "$origin/$release_branch" | grep -q "$branch"; then
				echo "Skipping $branch because it has been merged into $release_branch"
				continue 2
			fi
		done

		# if branch has been merged into develop, add it to the stale branches array
		if git branch -r --merged "$origin/develop" | grep -q "$branch"; then
			echo "$branch has been merged into develop but not into main or any release branch"
			stale_branches+=("$branch")
		fi
	done

	# if there are no stale branches, exit the script
	if [ ${#stale_branches[@]} -eq 0 ]; then
		echo "No stale branches found"
		exit 0
	fi

	echo "target\tbranch\tmerge-date\tauthor" 
	
	# loop through the stale branches and print them
	for stale_branch in ${stale_branches[@]}; do
		target_branch="develop"
		shared_commit=$(git merge-base $origin/$stale_branch $origin/develop)
		creation_date=$(git show -s --format=%ci $shared_commit)
		author=$(git show -s --format=%an $shared_commit)

		# print the branch information
		echo "[$target_branch]\t[$stale_branch]\t[$creation_date]\t[$author]"
	done
}

remove_stale_branches

