# Hazard-Model

- Come up with a list of possible covariates that should matter for default
prediction. Some possible sources are

  • Lecture on credit scoring

  • Data Dictionary

  • Lending Club

  • Prosper

  • Lend Academy

  • Nickel Steamroller

- Compute these explanatory variables

- Do a in-sample estimation and prediction. Follow these steps

  • Use the entire time period 2007-2015 for estimation

  • Run a PROC LOGISTIC model with DESCENDING option with
bankruptcy as the LHS variable and the variables in step 1 as
explanatory variables

  • Present the output and fit statistics for the model (output of proc
logistic).

- Do a out-of-sample prediction. Follow these steps

  • Divide the sample into in-sample estimation period (2007-2013)
and out of sample forecasting period (2014-2015)

  • Estimate the model with 2007-2013 data

  • Forecast default for 2014-2015 time period using the estimates
from 2007-2013 time period and explanatory variable data from
2014-2015

  • Rank the default probabilities into deciles (10 groups). Use PROC
RANK

  • Compute the number (and percentage of defaults) in each of the
10 groups during 2014-2015 time period.

  • A good model is one that has the majority of defaults in decile 1
or 2 and very few in other deciles

  • You can use other metrics like ROC curve etc., but you don’t
need to compute those measures

- Iterate steps 1-4 till you get a model with good out of sample performance
