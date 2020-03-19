
library(tidyverse)

#####################################################
# get set up with data and functions
#####################################################

# source function script
source("ipcc-c-model-functions.R")

# read in main climate data
# we'll use this as the basis for the model simulation
Dat_nest <- read_rds("model-data/bush-estate-1980-2070-climvars-100-samples.rds")

# yield data for bush estate's barley
Dat_yield <- read_csv("model-data/bush-estate-barley-yield-tha-1980-2070.csv")

# manure application for bush estate's barley
Dat_manure <- read_csv("model-data/bush-estate-manure-application-1980-2070.csv")

# sand percentage for soil at bush estate
sand_frac <- 0.47006 # sampled from sand % raster — no point reading in every time

#####################################################
# starting with monthly climate variables, condensing to annual modification factors (tfac and wfac)
#####################################################
Dat_nest <- Dat_nest %>%
  mutate(data_full = data_full %>%
           map(function(df){
             df %>%
               group_by(year) %>%
               summarise(wfac = wfac(precip = precip_mm, PET = pet_mm),
                         tfac = tfac(temp = temp_centigrade)) %>%
               ungroup()
           }))

#####################################################
# calculate crop-specific variables in the crop dataset
#####################################################

# C in crop residues
Dat_yield <- Dat_yield %>%
  mutate(C_res = C_in_residues(yield = yield_tha,
                               crop = "Barley",
                               frac_renew = 1,
                               frac_remove = 0.7),
         N_frac = N_frac(crop = "Barley"),
         lignin_frac = Lignin_frac(crop = "Barley"))

# calculate C inputs from manure
Dat_manure <- Dat_manure %>%
  mutate(C_man = map2_dbl(man_nrate, man_type, C_in_manure))

# select and join
Dat_crop <- left_join(Dat_yield %>%
                        select(year, yield_tha, C_res, N_frac, lignin_frac),
                      Dat_manure %>%
                        select(year, man_nrate, C_man),
                      by = "year") %>%
  mutate(C_tot = C_man + C_res)

# join to main model data
# also adding in sand fraction data here since it's an odd one out
Dat_nest <- Dat_nest %>%
  mutate(data_full = data_full %>%
           map(function(df){
             df %>%
               mutate(sand_frac = sand_frac) %>%
               left_join(Dat_crop, by = "year")
           }))



