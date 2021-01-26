#!/bin/bash

ls /data
python3 /writer.py
cd /data && git clone https://github.com/rawkintrevo/covid-blog/
cp -r /data/blog_posts/* /data/covid-blog/_posts
git config --global user.email "trevor.d.grant@gmail.com"
git config --global user.name "rawkintrevo"
cd /data/covid-blog && git add --all && git commit -am "new posts" && git push
