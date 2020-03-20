
library(tidyverse)

# read in barley yields and convert to relative (base year 2014)
Dat_yield <- read_csv("non-model-data/faostat-barley-yield-uk.csv") %>%
  select(year = Year, Value) %>%
  mutate(yield_rel = Value / Value[year == 2014]) %>%
  select(-Value)

# bush estate yield in t / ha from 2014 records
bush_estate_yield <- 142.5 / 40 # 142.5 tonnes total yield, 40 hectares

# convert dataset to bush estate's yields
Dat_yield <- Dat_yield %>%
  mutate(yield_tha = yield_rel * bush_estate_yield)

# plot
Dat_yield %>%
  ggplot(aes(x = year, y = yield_tha)) +
  geom_line()

# 10 year mean and sd for barley yield
yield_mean <- Dat_yield %>% tail(10) %>% pull(yield_tha) %>% mean()
yield_sd <- Dat_yield %>% tail(10) %>% pull(yield_tha) %>% sd()

# randomly generated barley yield to 2070 based on 10-year performance
set.seed(260592)
Dat_preds <- tibble(year = 2019:2070,
                    yield_tha = rnorm(n = length(2019:2070), mean = yield_mean, sd = yield_sd))

# bind simulation with historical data
Dat_yield <- bind_rows("historial" = Dat_yield,
                       "simulated" = Dat_preds,
                       .id = "origin")

# plot to check
Dat_yield %>%
  ggplot(aes(x = year, y = yield_tha, colour = origin)) +
  geom_line()

# write out data with filter to post-1980 (matching climate data)
# also adding variables here that will be required by model (doing here, not in model script,
# means students can manually modify the resulting .csv with effect on the model)
Dat_yield %>%
  filter(year >= 1980) %>%
  mutate(crop_type = "Barley",
         frac_renew = 1,
         frac_remove = 0.7,
         till_type = "full") %>%
  select(origin, year, crop_type, yield_tha, frac_renew, frac_remove, till_type) %>%
  write_csv("model-data/bush-estate-barley-yield-tha-1980-2070.csv")
