#!/bin/bash

if [ -d "/data/COVID-19" ]
then
  cd /data/COVID-19
  git pull
else
  git clone https://github.com/CSSEGISandData/COVID-19.git /data/COVID-19
fi

if [ ! -f /data/co-est2019-alldata.csv ]
then
  curl https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/co-est2019-alldata.csv -o /data/co-est2019-alldata.csv
fi

