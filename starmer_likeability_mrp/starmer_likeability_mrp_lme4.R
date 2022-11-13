# libraries --------------------------------------------------------------------
library(haven)
library(tidyverse)
library(lme4)
library(sf)
library(scico)
options(scipen = 999)

setwd("starmer_likeability_mrp")

# import british election study data -------------------------------------------

# this is Wave 23 of the British Election Study panel available to download here: 
# https://www.britishelectionstudy.com/data-objects/panel-study-data/ 

bes_location <- "C:/Users/Alex/Documents/Data/BES2019_W23_v23.0.dta"
bes <- haven::read_dta(bes_location)

# import constituency level predictors from BES
aux_location <- "C:/Users/Alex/Documents/Data/BES-2019-General-Election-results-file-v1.1.xlsx"
aux <- readxl::read_excel(aux_location) %>%
  select(
    ConstituencyName,
    pano,
    ONSConstID,
    Country,
    Region,
    Winner19,
    Con19,
    Lab15,
    Lab19,
    LD19,
    leaveHanretty,
    c11EthnicityWhiteBritish,
    c11Retired,
    c11DeprivedNone) %>%
  replace(is.na(.), 0)

# import poststratification frame ----------------------------------------------

# this frame was created by Professor Chris Hanretty and is available to download here: 
# https://journals.sagepub.com/doi/10.1177/1478929919864773#supplementary-materials 

psf_location <- "C:/Users/Alex/Documents/Data/hlv_psw.csv"
psf <- read.csv(psf_location, stringsAsFactors = FALSE)

# clean data to match psf ------------------------------------------------------

bes_clean <- bes %>%
  select(likeStarmer, likeLab, gor,pano,pcon,gender,age,p_housing,p_education,p_socgrade) %>%
  mutate(likeStarmer = as.integer(likeStarmer),
         likeLab = as.integer(likeLab)) %>%
  na_if(9999) %>%
  as_factor()

bes_clean <- bes_clean %>%
  mutate(
    housing = ifelse(p_housing == "Own â€“ outright" | p_housing == "Own â€“ with a mortgage", "Owns", "Rents"),
    sex = gender,
    hrsocgrd = case_when(
      p_socgrade == "A" | p_socgrade == "B" ~ "AB",
      p_socgrade == "C1" ~ "C1",
      p_socgrade == "C2" ~ "C2",
      p_socgrade == "D" | p_socgrade == "E" ~ "DE",
      TRUE ~ NA_character_),
    education = case_when(
      p_education == "City & Guilds certificate" ~ "Level 1",
      p_education == "City & Guilds certificate - advanced" ~ "Level 2",
      p_education == "Clerical and commercial" ~ "Level 1",
      p_education == "CSE grade 1, GCE O level, GCSE, School Certificate" ~ "Level 2",
      p_education == "CSE grades 2-5" ~ "Level 1",
      p_education == "GCE A level or Higher Certificate" ~ "Level 3",
      p_education == "No formal qualifications" ~ "No qualifications",
      p_education == "Nursing qualification (e.g. SEN, SRN, SCM, RGN)" ~ "Level 4/5",
      p_education == "ONC" ~ "Level 2",
      p_education == "Other technical, professional or higher qualification" ~ "Other",
      p_education == "Recognised trade apprenticeship completed" ~ "Level 2",
      p_education == "Scottish Higher Certificate" ~ "Level 3",
      p_education == "Scottish Ordinary/ Lower Certificate" ~ "Level 2",
      p_education == "Teaching qualification (not degree)" ~ "Level 4/5",
      p_education == "University diploma" ~ "Level 4/5",
      p_education == "University or CNAA first degree (e.g. BA, B.Sc, B.Ed)" ~ "Level 4/5",
      p_education == "University or CNAA higher degree (e.g. M.Sc, Ph.D)" ~ "Level 4/5",
      p_education == "Youth training certificate/skillseekers" ~ "Level 2",
      TRUE ~ NA_character_),
    age0 = cut(as.numeric(age), 
      breaks=c(-Inf, 19, 24, 29, 44, 59, 64, 74, Inf), 
      labels=c("16-19","20-24","25-29","30-44","45-59","60-64","65-74","75+"))) %>%
  select(-age,-p_housing,-p_education,-p_socgrade) 

# merge with aux data 
df <- bes_clean %>%
  merge(aux, by="pano")

# build model ------------------------------------------------------------------

# Like Starmer
starmer_model <-  lme4::lmer(
  'likeStarmer ~ 
  (1|pcon) + 
  (1|gor) +
  (1|age0) + 
  (1|age0:sex) + 
  (1|education) + 
  (1|hrsocgrd) + 
  sex +
  housing +
  Lab15 + 
  LD19 +
  leaveHanretty +
  c11DeprivedNone +
  c11Retired +
  c11EthnicityWhiteBritish',
  data = df
  )

summary(model)

# Like Labour
labour_model <-  lme4::lmer(
  'likeLab ~ 
  (1|pcon) + 
  (1|gor) +
  (1|age0) + 
  (1|education) + 
  (1|age0:education) + 
  (1|hrsocgrd) + 
  sex +
  housing +
  Lab15 + 
  leaveHanretty +
  c11DeprivedNone +
  c11Retired +
  c11EthnicityWhiteBritish',
  data = df
)

# model outputs
summary(labour_model)
plot(labour_model)
ranef(labour_model)
sjPlot::plot_model(labour_model, "re")
sjPlot::plot_model(labour_model, "est")

# poststratification -----------------------------------------------------------

# match psf to model
psf <- psf %>%
  merge(aux, by.x="GSSCode", by.y="ONSConstID") %>%
  rename(c(country = Country, pcon = GSSCode, gor = Region))

# predict onto psf
psf$likeStarmer <- predict(starmer_model, psf, allow.new.levels=T)
psf$likeLabour <- predict(labour_model, psf, allow.new.levels=T)

# combines estimates by constituency
mrp_estimates <- psf %>%
  group_by(country, Winner19, ConstituencyName, pcon) %>%
  summarise(likeStarmer = sum(likeStarmer*weight, na.rm=T),
            likeLabour = sum(likeLabour*weight, na.rm=T))

# plot comparison
ggplot(mrp_estimates, aes(y=likeLabour, x=likeStarmer)) +
  geom_point(aes(colour = Winner19), size=2) +
  theme_bw() + 
  scale_colour_manual(values = c(
    "blue", "darkgreen", "red", "orange", "green", "gold", "grey"
    ))

# display data -----------------------------------------------------------------

# map estimates
shapefile <- sf::read_sf("C:/Users/Alex/Documents/Data/Constituencies/Westminster_Parliamentary_Constituencies_(December_2019)_Boundaries_UK_BUC.shp") %>%
  merge(mrp_estimates, by.y = "pcon", by.x = "pcon19cd") %>%
  sf::st_transform(., 27700) %>%
  pivot_longer(., cols = c(likeLabour, likeStarmer))

labs <- c("Like Labour", "Like Starmer")
names(labs) <- c("likeLabour", "likeStarmer")

# contrast likeability
map <- ggplot(shapefile) +
  geom_sf(aes(fill=value), colour = "white", size = NA) + 
  theme_bw() +
  facet_wrap(~name, labeller = labeller(name = labs)) +
  labs(title = "Comparison of the Likeability of Labour and Kier Starmer",
       subtitle = "Constituency estimates modelled using Multilevel Regression and Poststratification",
       caption = "Please note the midpoint of the colour scale is not set to 5") +
  scale_fill_gradient2(
    low = "royalblue1", 
    mid = "gray85",
    high = "red3",
    midpoint = mean(shapefile$value),
    name = "Likeability of Labour\n& Starmer (0-10)") +
  theme(strip.text = element_text(size = 12, face = "bold"),
        plot.title = element_text(size = 14, face = "bold"),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

ggsave("Labour_Starmer_Likeability_Comparison.png", map, dpi=300, height=10, width=12)

# where is Kier an asset