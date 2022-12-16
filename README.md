# Multilevel Regression and Poststratification (MRP)

## Intro

Multilevel Regression and Poststratification (MRP or MrP) is an increasingly utilised method in survey research to make inferences about a target population from survey data that may not be representative of the target population.

MRP therefore has two primary uses. Firstly, MRP is used to correct for biased samples, for example, previous research has used MRP to predict the results of US elections from a [poll of Xbox users](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/04/forecasting-with-nonrepresentative-polls.pdf) (a highly unrepresentative sample of the US population).

Secondly, MRP is used for small area estimation. In 2017, [YouGov introduced MRP](https://yougov.co.uk/topics/politics/articles-reports/2017/06/09/how-yougovs-election-model-compares-final-result) to the UK polling industry by using the method to successfully measure voting intention at a constituency level from a single (albeit large) national poll with only a small number of responses in each constituency. They were one of the few pollsters that pointed to the likely shrinking of the Conservative majority.

The following examples show some of my experiments with MRP to investigate social and political questions that I find interesting.

## [Example 1: Estimating constituency voting intention using MRP](https://github.com/hymeram/mrp/tree/main/voting_intention)

#### MRP Seat Estimates of BES Voting Intention (May 2022)

| Party            | Weighted Survey Estimate | MRP Estimate | Turnout Adjusted MRP Estimate | MRP Seat Estimate |
|--------------|---------------|-------------|-----------------|------------|
| Labour           | 38.2%                    | 39.0%        | 37.7%                         | 326               |
| Conservative     | 30.4%                    | 30.0%        | 31.6%                         | 237               |
| SNP              | 4.0%                     | 4.2%         | 4.0%                          | 58                |
| Liberal Democrat | 10.4%                    | 10.0%        | 10.3%                         | 7                 |
| Plaid Cymru      | 0.6%                     | 0.7%         | 0.7%                          | 2                 |
| Green Party      | 6.7%                     | 6.2%         | 6.2%                          | 1                 |
| Reform UK        | 3.7%                     | 4.0%         | 4.1%                          | 0                 |
| Other            | 5.9%                     | 6.0%         | 5.4%                          | 1                 |

![](voting_intention/Maps/MPR_result_map.png)

![](voting_intention/Maps/MPR_result_map_by_edu.png)

## [Example 2: Where is Keir Starmer an electoral asset to Labour?](https://github.com/hymeram/mrp/tree/main/starmer_likeability_mrp)

How popular is Keir Starmer and where in the UK is he an electoral asset? The following example uses MRP on the latest British Election Study wave to measure his likeability by constituency and contrasts it with the likeability of the Labour Party more broadly.

To take a better look at where Starmer outperforms and underperforms Labour the map below shows areas where Starmer is more/less popular than the Labour Party. Starmer appears to be an electoral asset to Labour in areas outside of traditional Labour's territory, i.e. the rural South of England.

In Labour heartlands, Starmer is less popular than the Labour Party, this is especially true in the North West, the part of the UK where Starmer is least liked. Disconcertingly for Labour, in a lot of the target 'Red Wall' seats Starmer also appears less popular than the Labour Party as an organisation, potentially hindering Labour performance in this part of the UK.

![](starmer_likeability_mrp/Maps/Labour_Starmer_Net_Likeability.png)

Differences in attitudes towards Labour and Starmer by age are dramatic. Especially among those under 30, Starmer is substantially less liked than Labour as a whole in nearly every constituency. Among those over the age of 60, Starmer is generally more popular then the Labour Party as a whole, apart from a few areas of the UK (including much of North West England and South Wales).

![](starmer_likeability_mrp/Maps/Labour_Starmer_Net_Likeability_By_Age.png)

## Useful links:

-   [Multilevel Regression and Poststratification Case Studies](https://bookdown.org/jl5522/MRP-case-studies/)

-   [An Introduction to Multilevel Regression and Post-Stratification for Estimating Constituency Opinion](https://journals.sagepub.com/doi/10.1177/1478929919864773)

-   [Forecasting elections with non-representative polls](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/04/forecasting-with-nonrepresentative-polls.pdf)

-   [Deep Interactions with MRP: Election Turnout and Voting Patterns Among Small Electoral Subgroups](http://www.stat.columbia.edu/~gelman/research/published/misterp.pdf)

-   [The Geography of Racially Polarized Voting: Calibrating Surveys at the District Level](https://osf.io/mk9e6/)

-   [Using Multilevel Regression and Poststratification to Estimate Dynamic Public Opinion](http://www.stat.columbia.edu/~gelman/research/unpublished/MRT(1).pdf)

-   [Model-Based Pre-Election Polling for National and Sub-National Outcomes in the US and UK](https://benjaminlauderdale.net/files/papers/mrp-polling-paper.pdf)

-   [General Election Vote Intention: Multilevel regression and post-stratification (MRP) estimates](https://www.opinium.com/wp-content/uploads/2022/10/MRP_Tables_2022.pdf)

-   [Comparing Strategies for Estimating Constituency Opinion from National Survey Samples](https://www.cambridge.org/core/journals/political-science-research-and-methods/article/comparing-strategies-for-estimating-constituency-opinion-from-national-survey-samples/60701055350642BFA9BD5FF6EE469BC2#article)
