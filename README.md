# LibaryCleaner
## Exampel for runing on a smb from windows(NAS)
```.\transcode_movies.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1```

```.\remove_pretranscoded.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1 -WhatIf```

## Exampel for runing on Linux(Debian)

~~```$0 -i /home/user/Movies -r 1080p -a 2.0```~~ (Work in progress)

```./remove_pretranscoded.sh ./movies 1440p 5.1 true```

## Tags
### Pretranscode tags
- -i   Path to movie library
- -r   Target resolution (e.g. 720p, 1080p, 1440p)
- -a   Target audio layout (2.0, 5.1, 7.1)
- -h for help message

### Cleanup tags (.ps1)
- -i   Path to movie library
- -r   Target resolution (e.g. 720p, 1080p, 1440p)
- -a   Target audio layout (2.0, 5.1, 7.1)
- -WhatIf Runs with print out but dosen't remove anything

### Cleanup (.sh)
it just evaluates teh placment of varibels so the order is.
1. Path to movie library
2. Resolution to keep (e.g. 720p, 1080p, 1440p)
3. Audio layout to keep (2.0, 5.1, 7.1)
4. Dry run/WhatIf (true, false)