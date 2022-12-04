# Multilevel Regression and Poststratification (MRP)

## Intro

Multilevel Regression and Poststratification (MRP or MrP) is an increasingly utilised method in survey research to make inferences about a target population from survey data that may not be representative of the target population.

MRP therefore has two primary uses. Firstly, MRP is used to correct for biased samples, for example, previous research has used MRP to predict the results of US elections from a [poll of Xbox users](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/04/forecasting-with-nonrepresentative-polls.pdf) (a highly unrepresentative sample of the US population).

Secondly, MRP is used for small area estimation. In 2017, [YouGov introduced MRP](https://yougov.co.uk/topics/politics/articles-reports/2017/06/09/how-yougovs-election-model-compares-final-result) to the UK polling industry by using the method to successfully measure voting intention at a constituency level from a single (albeit large) national poll with only a small number of responses in each constituency. They were one of the few pollsters that pointed to the likely shrinking of the Conservative majority.

The following examples show some of my experiments with MRP to investigate social and political questions that I find interesting.

## [Example 1: Where is Keir Starmer's an electoral asset to Labour?](https://github.com/hymeram/mrp/tree/main/starmer_likeability_mrp)

How popular is Keir Starmer and where in the UK is he an electoral asset? The following example uses MRP on the latest British Election Study wave to measure his likeability by constituency and contrasts it with the likeability of the Labour Party more broadly.

To take a better look at where Starmer outperforms and underperforms Labour the map below shows areas where Starmer is more/less popular than the Labour Party. Starmer appears to be an electoral asset to Labour in areas outside of traditional Labour's territory, i.e. the rural South of England.

In Labour heartlands, Starmer is less popular than the Labour Party, this is especially true in the North West, the part of the UK where Starmer is least liked. Disconcertingly for Labour, in a lot of the target 'Red Wall' seats Starmer also appears less popular than the Labour Party as an organisation, potentially hindering Labour performance in this part of the UK.

![](voting_intention/Maps/Labour_Starmer_Net_Likeability.png)

Differences in attitudes towards Labour and Starmer by age are dramatic. Especially among those under 30, Starmer is substantially less liked than Labour as a whole in nearly every constituency. Among those over the age of 60, Starmer is generally more popular then the Labour Party as a whole, apart from a few areas of the UK (including much of North West England and South Wales).

![](voting_intention/Maps/Labour_Starmer_Net_Likeability_By_Age.png)

## [Example 2: Estimating constituency voting intention using MRP](https://github.com/hymeram/mrp/tree/main/voting_intention)

| Party                  | Vote Intention (%) [95% CI] | MRP Seat Estimate |
|------------------------|-----------------------------|-------------------|
| Labour                 | 28.2 [27.6 - 28.8]          | 222               |
| Conservative           | 22.4 [21.9 - 23.0]          | 341               |
| SNP                    | 2.9 [2.7 - 3.1]             | 57                |
| Liberal Democrat       | 7.6 [7.3 - 8.0]             | 7                 |
| Plaid Cymru            | 0.4 [0.37 - 0.53]           | 2                 |
| Green Party            | 5.0 [4.7 - 5.2]             | 1                 |
| Reform UK              | 2.7 [2.5 - 3.0]             | 0                 |
| Other                  | 1.7 [1.5 - 1.8]             | 1                 |
| *Don't know*           | 20 [19.6 - 20.7]            | \-                |
| *I would/did not vote* | 8.8 [8.3 - 9.2]             | \-                |

![](voting_intention/Maps/MPR_result_map.png)

## Useful links:

Intros to MRP:

-   [Multilevel Regression and Poststratification Case Studies (bookdown.org)](https://bookdown.org/jl5522/MRP-case-studies/)

-   [An Introduction to Multilevel Regression and Post-Stratification for Estimating Constituency Opinion - Chris Hanretty, 2020 (sagepub.com)](https://journals.sagepub.com/doi/10.1177/1478929919864773) (also shows useful code in the supplementary materials)

Dynamic MRP (MRP over time):

-   <http://www.stat.columbia.edu/~gelman/research/unpublished/MRT(1).pdf>

Interesting Papers:

-   [Forecasting elections with non-representative polls (microsoft.com)](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/04/forecasting-with-nonrepresentative-polls.pdf)
-   [Deep Interactions with MRP: Election Turnout and Voting Patterns Among Small Electoral Subgroups (columbia.edu)](http://www.stat.columbia.edu/~gelman/research/published/misterp.pdf)

Use case for UK polling:

-   [General Election Vote Intention: Multilevel regression and post-stratification (MRP) estimates (opinium.com)](https://www.opinium.com/wp-content/uploads/2022/10/MRP_Tables_2022.pdf)

Helpful code :

-   [philswatton/mrpLR (github.com)](https://github.com/philswatton/mrpLR) (especially useful script for making poststratification frames using survey raking)
