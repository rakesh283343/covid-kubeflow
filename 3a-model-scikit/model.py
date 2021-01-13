import pandas as pd
from sklearn.linear_model import LinearRegression, Ridge
import numpy as np
from scipy import stats

data = pd.read_csv('flat_file.csv')


geos = list(set(data['Province_State'].to_list()))
dropGeos = ['Princess', "Islands", "Guam", "Puerto"]
for g in geos:
    if any([p in g for p in dropGeos]):
        continue
    state_data = data[data['Province_State'] == g]
    X = pd.get_dummies(state_data['FIPS'], drop_first=True, sparse= True)
    X['y'] = state_data['newCases']
    X['pActive'] = state_data['pActive']
    X['herdImmune'] = state_data['herdImmune']
    X['population'] = state_data['population']
    X = X.dropna()
    y = X['y']
    X = X.drop('y', 1)
    model = LinearRegression(normalize=False, n_jobs=4).fit(X,y)
    break
    #model = Ridge(normalize=False, solver='lsqr').fit(X,y)



### Get stats:
def getStats(lm, X, y):
    params = np.append(lm.intercept_,lm.coef_)
    predictions = lm.predict(X)

    newX = X
    newX['Constant'] = 1.0
    MSE = (sum((y-predictions)**2))/(len(newX)-len(newX.columns))

    # Note if you don't want to use a DataFrame replace the two lines above with
    # newX = np.append(np.ones((len(X),1)), X, axis=1)
    # MSE = (sum((y-predictions)**2))/(len(newX)-len(newX[0]))

    var_b = MSE*(np.linalg.inv(np.dot(newX.T,newX)).diagonal())
    sd_b = np.sqrt(var_b)
    ts_b = params/ sd_b

    p_values =[2*(1-stats.t.cdf(np.abs(i),(len(newX)-len(newX[0])))) for i in ts_b]

    sd_b = np.round(sd_b,3)
    ts_b = np.round(ts_b,3)
    p_values = np.round(p_values,3)
    params = np.round(params,4)

    myDF3 = pd.DataFrame()
    myDF3["Coefficients"],myDF3["Standard Errors"],myDF3["t values"],myDF3["Probabilities"] = [params,sd_b,ts_b,p_values]
    print(myDF3)
