function RemoveStaleBranches() {
    Write-Output "Fetching remote branches..."
    
    # run `git fetch` to get the latest remote branches
    git fetch

    # if `git fetch` fails, exit the script
    if ($LASTEXITCODE -ne 0) {
        Write-Output "git fetch failed; $LASTEXITCODE"
        Exit 0
    }

    # get the remote origin name 
    $origin=(git remote -v | Select-String fetch)
    $origin=($origin -split "\s+")[0]

    # get the branch names and store them in an array. Ignore the main and any branch starting with release.
	$branches=(git branch -r | Select-String -Pattern "main" -NotMatch | Select-String -Pattern "develop" -NotMatch | Select-String -Pattern "release" -NotMatch | Select-String -Pattern "HEAD" -NotMatch | ForEach-Object {($_ -split "$origin/")[1]})

    # get all release branches 
    $release_branches=(git branch -r | Select-String -Pattern "release*" | ForEach-Object {($_ -split "$origin/")[1]} )

    # create an empty array to store the stale branches 
    $stale_branches=@()

    foreach ($branch in $branches) {
        # if branch has been merged into main, skip it 
		if (git branch -r --merged "$origin/main" | Select-String -Pattern $branch) {
			Write-Output "Skipping $branch because it has been merged into main"
            continue
        }
       
        # loop through the release branches and check if the branch has been merged into any of them
        foreach($release_branch in $release_branches) {
            # if branch has been merged into release branch, skip it
            if (git branch -r --merged "$origin/$release_branch" | Select-String -Pattern $branch) {
                Write-Output "Skipping $branch it has been merged into $release_branch"
                continue 2
            }
        }

        # if branch has been merged into develop, add it to the stale branches array
        if (git branch -r --merged "$origin/develop" | Select-String -Pattern $branch) {
            Write-Output "$branch has been merged into develop but not into main or any release branch"
            $stale_branches += $branch
        }
    }

    # if there are no stale branches, exit the script
    if ($stale_branches.Length -eq 0) {
        Write-Output "No stale branches found"
        Exit 0
    }

    Write-Output "[target] `t[branch] `t[merge-date] `t[author]"

    foreach ($stale_branch in $stale_branches) {
        $shared_commit=(git merge-base $origin/$stale_branch $origin/develop)
        $creation_date=(git show -s --format=%ci $shared_commit)
		$author=(git show -s --format=%an $shared_commit)
        Write-Output "develop `t$stale_branch `t$creation_date `t$author"
    }
}

RemoveStaleBranches