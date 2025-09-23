# LibaryCleaner
## Exampel for runing on a smb from windows(NAS)
```.\transcode_varibel.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1```

```.\transcode_auto.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1```

```.\remove_pretranscoded.ps1 -i \\192.168.1.220\film_nas\movies -r 1440p -a 5.1 -WhatIf```

## Exampel for runing on Linux(Debian)

```./transcode_varibel.sh -i /path/to/library -r 720p -a 2.0```(Work in progress)

~~```./transcode_auto.sh -i ./movies -r 1440p -a 5.1```~~(Need fixing)

```./remove_pretranscoded.sh ./movies 1440p 7.1 true```

## Tags
### Varibel/Auto tags
- -i   Path to movie library
- -r   Target resolution (e.g. 720p, 1080p, 1440p)
- -a   Target audio layout (2.0, 5.1, 7.1)
- -h for help message
The difrance is the fixed settings for bitrate, audio layout and codac while auto adjust dependiong on source. Mostly to avoid reworking 2.0 into 5.1 adn when not reworking the audio it will lett the codac be unchanged. Bit rate will max out at 15Mb/s if the source is lower it will adopt that value.

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