line-bot-google-alert
====



# require
perl

# setup
```
cd line-bot-google-alert
carton install
```

and edit setting.conf.

# execute
carton exec plackup app.psgi

# how to use
- access 'http://example.com:5000/news'

e.g)
```
$ crontab -l
0 * * * * curl http://localhost:5000/news
```

