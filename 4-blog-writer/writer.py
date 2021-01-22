import os

"""
1. Load Flat File- Load dics of model summaries `d[modelType][state] = pd.DataFrame
1a. Get list of FIPS for each state from Flat File
2. For each FIPS
2a. Short blurb on model results for each model
2b. Create charts for statistics of interest
2bi. Draw scatter plot of FIPS_factor intercept/against:dateInt and highlight for individual FIPS
2bii. Chart of estimated actives over time
2biii. Chart of pActive over time vs state average.
2c. Write output to disk
3. (Maybe in bash after program) clone/pull Blog site- copy to kubeflow.party.
"""

import pandas as pd
from os import listdir

df = pd.read_csv("flat_file.csv")

models = {model : \
              {geo.replace(".csv", "").strip() : \
                   pd.read_csv(f"model_summaries/{model}/{geo}") \
               for geo in listdir(f"model_summaries/{model}") \
               } \
          for model in listdir('model_summaries/') }

fips = df['FIPS'].unique().tolist()

from datetime import datetime, timedelta
def postFromTemplate(city: str,
                     state: str,
                     fips: str,
                     lastNdays: int,
                     newCases: int,
                     newRecovery: int,
                     population: int,
                     herdImmune: float,
                     pActive: float,
                     estimatedActive: int,
                     synopsis: str):
    todaysDate = datetime.today().strftime("%Y-%m-%d")
    fname = f'{todaysDate}-{city}-{state}.markdown'

    s = f"""---
layout: post
title:  "Update for {city} County, {state} - {todaysDate}"
date:   {todaysDate} 01:01:29 -0600
categories: [{state}]
tags: [{city}-{state}]
---

# {city} County, {state}
#### Updated {todaysDate}

## Quick Facts

In the last {lastNdays} days[3] we project there have been
- *{newCases:.0f}* new cases of COVID-19
- *{newDeath:.0f}* people have died of COVID-19
- *{newRecovery:.0f}* people have recovered from COVID-19[1]

The population in this census area is {population}. By our calculations:
- {(100*herdImmune):.2f}% of the population have had COVID-19.[2]
- {(100*pActive):.2f}% of the population or {estimatedActive} people are actively fighting the virus.

## Synopsis

Comming soon...
{synopsis}

#### Footnotes

[1] Most US CDC offices do give any recovery statistics- we base this on a formula which looks at confirmed new cases
15 days ago (the average recovery time) and deaths over the last 7 days.

[2] Herd Immunity is thought to take effect at around ~70-80%

[3] Due to reporting delays, this data may be incomplete.
 
    """
    ## make directory
    try:
        os.makedirs(f"blog_posts/{state}/{city}")
    except FileExistsError:
        # directory already exists
        pass
    with open(f'blog_posts/{state}/{city}/{fname}', 'w') as f:
        f.write(s)

for f in fips[1:]:
    tmpDf = df[df['FIPS'] == f]
    if tmpDf.shape[0] < 8:
        continue
    state = tmpDf['Province_State'].iloc[0]
    stateDf =  models['lm'][state]
    city = tmpDf['Admin2'].iloc[0]
    last7daysDf = tmpDf[tmpDf['date'] > (datetime.today() - timedelta(8)).strftime("%Y-%m-%d")]
    fipsStr = str(tmpDf['FIPS'].iloc[0]).zfill(5)
    newCases = last7daysDf['newCases'].sum()
    newDeath = last7daysDf['newDeaths'].sum()
    newRecoveries = last7daysDf['newRecoveries'].sum()
    intercept = stateDf[stateDf['Unnamed: 0'] == '(Intercept)'].values.tolist()
    dateInt = models['lm'][state][models['lm'][state]['Unnamed: 0']=='dateInt'].values.tolist()
    special_facts = [r for r in models['lm'][state].values.tolist() if str(f) in r[0]]
    postFromTemplate(city, state, fipsStr, 7, newCases, newRecoveries, \
                     tmpDf['population'].iloc[-1], tmpDf['herdImmune'].iloc[-1], \
                     tmpDf['pActive'].iloc[-1], tmpDf['estimatedActive'].iloc[-1], "")
