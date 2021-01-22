#!/bin/bash

echo "refreshing covid data"
cd 1-get-data/COVID-19
git pull --ff-only
cd ../../
echo "prepping data for modeling"
python3 2-etl/prep_data.py
echo "modeling data"
Rscript 3z-model-using-R/model.R
echo "writing blog posts"
python3 4-blog-writer/writer.py

echo "posting blog posts"
cp -r blog_posts/* ../covid-blog/_posts
cd ../covid-blog
git add --all
git commit -am "new posts"
git push
#rm blog_posts/*
