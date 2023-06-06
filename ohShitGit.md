#### Oh shit, accidently pushed a repo into remote, need to delete 
```diff
git push --delete origin temp_branch
```

#### Oh shit, accidently commited the passwords in the branch and pushed manny commit, reseeting the file back to old including erasing in commit history 
```diff
git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch my_sensitiveFile' --prune-empty --tag-name-filter cat 01c859dd7d34017efe4a722734b2eee80ed10c64..HEAD
# where 01c859dd7d34017efe4a722734b2eee80ed10c64 is the commit hashid from which commit it has to be removed
```

