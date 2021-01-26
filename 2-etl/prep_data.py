from datetime import timedelta, date, datetime
from os import path
import pandas as pd

DATA_DIR='/data/COVID-19/csse_covid_19_data/csse_covid_19_daily_reports'
POPULATION_CSV='/data/co-est2019-alldata.csv'

def daterange(start_date, end_date):
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)

start_date = date(2020,4,22)
end_date = datetime.now().date()

records = []
for d in daterange(start_date, end_date):
    day = d.strftime('%m-%d-%Y')
    if path.exists(f"{DATA_DIR}/{day}.csv"):
        df = pd.read_csv(f"{DATA_DIR}/{day}.csv")
        df['date'] = datetime.strptime(day, "%m-%d-%Y").strftime('%Y-%m-%d')
        records = records + df.to_dict('records')
    else:
        print(f"{DATA_DIR}/{day}.csv not found...")


print(f"Found {len(records)} records.")

"""
Now we need to add metrics like:
 1. Active Cases
 2. Recoveries Total and New
 3. New Cases (confirmed today - confirmed yesterday
 4. New Deaths

Plan
----
First we need to assign new cases every day (all new on first day of reporting)

Then get "New Confirmed" and "New Deaths"

Then Check if "recovered" is > 0- assuming its not- infer recoveries.
- Look at new cases N_1 days ago (where N is average time to recovery or death)
- Now look at deaths on N_2 days ago (I know, this is kind of sloppy, but we can make it better later, cant take sum or you'll double count).
- New cases from step 1 - deaths over last N days = recoveries.
- Issue: Have to calculate deaths since that is a longer. E.g. We can only "call" recoveries for N_2 days ago. Also, 
  must do deaths first. Recovered today = People infect N_1 days ago minus people who die (N_2-N_1) days in the future. 
   

Once we have New Cases, Deaths, and Recoveries- Active cases is trvial. 
"""

records = [r for r in records if pd.notnull(r['FIPS'])]
records_by_fips = {}
for r in records:
    tmp = records_by_fips.get(r['FIPS'], {})
    records_by_fips[r['FIPS']] = tmp
    tmp[r['date']] = r
    records_by_fips[r['FIPS']].update(tmp)

print("Indexed by FIPS/date")

TIME_TO_RECOVER = 15
"""
Source: https://www.cdc.gov/coronavirus/2019-ncov/hcp/duration-isolation.html
which cites
> The likelihood of recovering replication-competent virus also declines after onset of symptoms. For patients with mild to moderate COVID-19, replication-competent virus has not been recovered after 10 days following symptom onset (CDC, unpublished data, 2020; Wölfel et al., 2020; Arons et al., 2020; Bullard et al., 2020; Lu et al., 2020; personal communication with Young et al., 2020; Korea CDC, 2020). Recovery of replication-competent virus between 10 and 20 days after symptom onset has been documented in some persons with severe COVID-19 that, in some cases, was complicated by immunocompromised state (van Kampen et al., 2020). However, in this series of patients, it was estimated that 88% and 95% of their specimens no longer yielded replication-competent virus after 10 and 15 days, respectively, following symptom onset. 
"""

TIME_TO_DEATH = 19
"""
Source: https://www.drugs.com/medical-answers/covid-19-symptoms-progress-death-3536264/
"""
def strToIntSafe(c):
    if pd.notnull(c):
        return c
    else:
        return 0

for f in records_by_fips.keys():
    for d in records_by_fips[f].keys():
        currentRecord = records_by_fips[f][d]
        currentDate = datetime.strptime(currentRecord['date'], "%Y-%m-%d")
        yesterdayDate = currentDate - timedelta(days=1)
        yesterdayRecord = records_by_fips[f].get(yesterdayDate.strftime("%Y-%m-%d"))
        if yesterdayRecord is None:
            continue
        yesterdayActive = strToIntSafe(yesterdayRecord['Active'])
        yesterdayDeaths = strToIntSafe(yesterdayRecord['Deaths'])
        todayActive = strToIntSafe(currentRecord['Active'])
        todayDeaths = strToIntSafe(currentRecord['Deaths'])
        records_by_fips[f][d]['newCases'] = todayActive - yesterdayActive
        records_by_fips[f][d]['newDeaths'] = todayDeaths - yesterdayDeaths

print("Calculated daily newCases/newDeaths")

for f in records_by_fips.keys():
    for d in records_by_fips[f].keys():
        currentRecord = records_by_fips[f][d]
        currentDate = datetime.strptime(currentRecord['date'], "%Y-%m-%d")
        deathdayDate = currentDate + timedelta(days=TIME_TO_DEATH)
        deathdayRecord = records_by_fips[f].get(deathdayDate.strftime("%Y-%m-%d"))
        if deathdayRecord is None:
            continue
        if deathdayRecord.get('newDeaths') is None:
            continue
        records_by_fips[f][d]['newCasesWhoWillDie'] = deathdayRecord['newDeaths']
        if currentRecord.get('newCases') is None:
            continue
        recoveryDate = currentDate + timedelta(days=TIME_TO_RECOVER)
        if records_by_fips[f].get(recoveryDate.strftime("%Y-%m-%d")) is None:
            recoveryDate = recoveryDate + timedelta(days= 1)
            if records_by_fips[f].get(recoveryDate.strftime("%Y-%m-%d")) is None:
                if currentRecord['newCases'] == 0:
                    continue
        records_by_fips[f][recoveryDate.strftime("%Y-%m-%d")]['newRecoveries'] = \
            currentRecord['newCases'] - deathdayRecord['newDeaths']

print("inferred recoveries daily")
for f in records_by_fips.keys():
    estimatedActive = 0
    for d in records_by_fips[f].keys():
        estimatedActive = estimatedActive + records_by_fips[f][d].get('newCases',0) - (records_by_fips[f][d].get('newDeaths',0) +records_by_fips[f][d].get('newRecoveries',0))
        records_by_fips[f][d]['estimatedActive'] = estimatedActive

pop_df = pd.read_csv(POPULATION_CSV, encoding='iso-8859-1')
pop_df['FIPS'] = pop_df['STATE'].astype(str).str.zfill(2) + pop_df['COUNTY'].astype(str).str.zfill(3)

for f in records_by_fips.keys():
    for d in records_by_fips[f].keys():
        fips = str(int(f)).zfill(5)
        if pop_df[pop_df['FIPS']==fips]['POPESTIMATE2019'].shape[0] == 0:
            continue
        pop = pop_df[pop_df['FIPS']==fips]['POPESTIMATE2019'].iloc[0]
        herdImmune = records_by_fips[f][d]['Confirmed'] / pop
        pActive = records_by_fips[f][d]['estimatedActive'] / pop
        pNew = records_by_fips[f][d].get('newCases',0) / pop
        records_by_fips[f][d]['population'] = pop
        records_by_fips[f][d]['herdImmune'] = herdImmune
        records_by_fips[f][d]['pActive'] = pActive
        records_by_fips[f][d]['pNew'] = pNew

        """New data points I want:
        1) % of population now "immune" (bc they've had it already)
        2) new cases as % of population
        3) total population
        """


"""Lag deaths/newcases e.g. newCases_today = fn(newCases_t-1, newCases_t-2, ..."""
flat_records = [records_by_fips[f][d] for f in records_by_fips.keys() for d in records_by_fips[f].keys()]

for i in range(len(flat_records)):
    flat_records[i]['newCases'] = flat_records[i].get('newCases', 0)

for i in range(len(flat_records)):
    flat_records[i]['FIPS'] = str(int(flat_records[i]['FIPS'])).zfill(5)

drop_terr = ["Princess", "Islands", "Guam", "Puerto", "District"]
flat_record_redux = list()
for i in range(len(flat_records)):
    if flat_records[i].get('population') is None:
        continue
    if any([t in flat_records[i]['Province_State'] for t in drop_terr]):
        continue
    else:
        flat_record_redux.append(flat_records[i])


pd.DataFrame.from_records(flat_record_redux).to_csv("/data/flat_file.csv")

#
# flat_records_sm = [records_by_fips[f][d] \
#                 for f in list(records_by_fips.keys())[:120] \
#                 for d in records_by_fips[f].keys() \
#                 ]
#
#
# pd.DataFrame.from_records(flat_records_sm).to_csv("flat_file_sm.csv")
