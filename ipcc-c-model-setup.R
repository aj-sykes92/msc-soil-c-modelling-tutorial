
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
Dat_crop <- read_csv("model-data/bush-estate-barley-yield-tha-1980-2070.csv")

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

# C inputs from crop residues and manure
Dat_crop <- Dat_crop %>%
  mutate(C_res = pmap_dbl(list(yield_tha, crop_type, frac_renew, frac_remove),
                          C_in_residues)) %>%
  left_join(Dat_manure, by = "year") %>%
  mutate(C_man = pmap_dbl(list(man_nrate, man_type),
                          C_in_manure),
         N_frac = pmap_dbl(list(crop_type, man_type, C_res, C_man),
                           N_frac),
         lignin_frac = pmap_dbl(list(crop_type, man_type, C_res, C_man),
                                Lignin_frac))
rm(Dat_manure)
stop()
# select and join
Dat_crop <- left_join(Dat_yield %>%
                        select(year, yield_tha, C_res, N_frac, lignin_frac),
                      Dat_manure %>%
                        select(year, man_nrate, C_man),
                      by = "year") %>%
  mutate(C_tot = C_man + C_res,
         N_frac = N_frac(crop_type = "Barley",
                         manure_type = man_type))

# join to main model data
# also adding in sand fraction data here since it's an odd one out
Dat_nest <- Dat_nest %>%
  mutate(data_full = data_full %>%
           map(function(df){
             df %>%
               mutate(sand_frac = sand_frac) %>%
               left_join(Dat_crop, by = "year")
           }))



