library(tidyverse)

setwd("../data")
infiles <- list.files(pattern = "*.csv")
d_list <- lapply(infiles, read.csv)
d <- do.call(rbind, d_list) %>% 
  mutate(duration = c(interval[-1], 0),
         interval = NULL) %>%
  group_by(participant_code) %>%
  mutate(timestamp = timestamp - timestamp[1]) %>%
  ungroup

rm(d_list, infiles)



# Plot key strokes as score:

red_events <- d %>% 
  select(timestamp, red, participant_code) %>%
  mutate(
    on = if_else(
      red == 1L & (lag(red) == 0L | is.na(lag(red))),
      timestamp, NA_real_, NA_real_),
    off = if_else(
      red == 0L & lag(red) == 1L,
      timestamp, NA_real_, NA_real_)
  ) %>% 
  filter(!is.na(on) | !is.na(off)) %>% 
  select(on, off, participant_code) %>% 
  mutate(off = lead(off)) %>% 
  filter(!is.na(on)) %>% 
  mutate(key = "red")

green_events <- d %>% 
  select(timestamp, green, participant_code) %>%
  mutate(
    on = if_else(
      green == 1L & (lag(green) == 0L | is.na(lag(green))),
      timestamp, NA_real_, NA_real_),
    off = if_else(
      green == 0L & lag(green) == 1L,
      timestamp, NA_real_, NA_real_)
  ) %>% 
  filter(!is.na(on) | !is.na(off)) %>% 
  select(on, off, participant_code) %>% 
  mutate(off = lead(off)) %>% 
  filter(!is.na(on)) %>% 
  mutate(key = "green")

white_events <- d %>% 
  select(timestamp, white, participant_code) %>%
  mutate(
    on = if_else(
      white == 1L & (lag(white) == 0L | is.na(lag(white))),
      timestamp, NA_real_, NA_real_),
    off = if_else(
      white == 0L & lag(white) == 1L,
      timestamp, NA_real_, NA_real_)
  ) %>% 
  filter(!is.na(on) | !is.na(off)) %>% 
  select(on, off, participant_code) %>% 
  mutate(off = lead(off)) %>% 
  filter(!is.na(on)) %>% 
  mutate(key = "white")

black_events <- d %>% 
  select(timestamp, black, participant_code) %>%
  mutate(
    on = if_else(
      black == 1L & (lag(black) == 0L | is.na(lag(black))),
      timestamp, NA_real_, NA_real_),
    off = if_else(
      black == 0L & lag(black) == 1L,
      timestamp, NA_real_, NA_real_)
  ) %>% 
  filter(!is.na(on) | !is.na(off)) %>% 
  select(on, off, participant_code) %>% 
  mutate(off = lead(off)) %>% 
  filter(!is.na(on)) %>% 
  mutate(key = "black")

events <- rbind(red_events, white_events, green_events, black_events) %>% 
  mutate(key = as.factor(key),
         condition = str_sub(participant_code, start = -1) %>% as.factor,
         participant = str_sub(participant_code, start = 10, end = 11),
         timestamp = on,
         duration = off - on,
         on = NULL, off = NULL) %>%
  arrange(participant_code, timestamp)

levels(events$condition) <- c("Control", "Unmarked", "Marked", "Unm.Disjunct", "Mkd.Disjunct")

rm(black_events, green_events, red_events, white_events)





combo_level_order <- c("BG", "BR", "BW", "GR", "GW", "RW", "BGR", "BGW", "BRW", "GRW", "BGRW")

combos <- d %>%
  mutate(cb = red + 2*green + 4*white + 8*black,
         combo = case_when(
           cb == 0 ~ NA_character_,
           cb == 1 ~ NA_character_,
           cb == 2 ~ NA_character_,
           cb == 4 ~ NA_character_,
           cb == 8 ~ NA_character_,
           cb == 3 ~ "GR",
           cb == 5 ~ "RW",
           cb == 9 ~ "BR",
           cb == 6 ~ "GW",
           cb == 10 ~ "BG",
           cb == 12 ~ "BW",
           cb == 7 ~ "GRW",
           cb == 13 ~ "BRW",
           cb == 11 ~ "BGR",
           cb == 14 ~ "BGW",
           cb == 15 ~ "BGRW"
         ),
         cb = NULL,
         condition = str_sub(participant_code, start = -1) %>% as.factor,
         participant = str_sub(participant_code, start = 10, end = 11),
         combo = fct_relevel(combo, combo_level_order)) %>% 
  filter(!is.na(combo)) %>% 
  mutate(y = "combo")

levels(combos$condition) <- c("Control", "Unmarked", "Marked", "Unm.Disjunct", "Mkd.Disjunct")




events$combo <- events$key

# synchronize combos and single key press data for glueing together:
combos_plot <- combos %>% 
  select(condition, participant, timestamp, duration, combo, y)
events_plot <- events %>%
  select(condition, participant, timestamp, duration, combo, key) %>% 
  mutate(y = as.character(key), key = NULL)

# glue:
keys_combos_plot <- rbind(combos_plot, events_plot) %>% 
  arrange(condition, participant, timestamp) %>% 
  mutate(combo = fct_relevel(combo,
                             c("black", "green", "red", "white", combo_level_order)),
         y = as.factor(y),
         y = fct_relevel(y, c("combo", "black", "green", "red", "white")),
         # decorations stating the condition displayed in facets (facets officially are kids):
         participant = as.factor(participant),
         participant = fct_inorder(participant)
  )

# decoration: condition per child into each facet:
cond_deco <- keys_combos_plot %>% 
  group_by(participant) %>% 
  summarize(condition = condition[2])





# mark when the light goes on:
keys_combos_plot <- keys_combos_plot %>% 
  group_by(participant) %>% 
  # counter increases with every unique 2-combo:
  mutate(nth_unique = cumsum(
    combo %in% c("BG", "BR", "BW", "GR", "GW", "RW") & !duplicated(combo)),
    success = nth_unique == 3 & lag(nth_unique) < 3,
    nth_unique = NULL
    ) %>% ungroup

post_success_phase <- keys_combos_plot %>% 
  select(condition, participant, timestamp, duration, success) %>% 
  filter(success == TRUE) %>% 
  mutate(post_start = timestamp,
         timestamp = NULL, duration = NULL, success = NULL)





# hack: get width left of 0 for manual decoration:
xoffs <- max(keys_combos_plot$timestamp + keys_combos_plot$duration) * 0.01 /1000

ggplot(keys_combos_plot) +
  geom_segment(aes(x = timestamp / 1000,
                   xend = (timestamp + duration) / 1000,
                   y = y,
                   yend = y,
                   color = combo),
               size = 3) +
  geom_hline(yintercept = 1,
             color = "white",
             alpha = 0.3,
             size = 6) +
  geom_vline(data = keys_combos_plot %>% filter(success == TRUE),
             aes(xintercept = timestamp / 1000),
             color = "blue",
             size = 1,
             alpha = .5) +
  geom_rect(data = cond_deco,
            aes(fill = condition),
            color = NA,
            xmin = -xoffs, xmax = -xoffs + 1,
            ymin = 0.5, ymax = 5.5) +
  geom_text(data = cond_deco,
            aes(label = condition),
            x = -xoffs, y = 3,
            angle = 90, color = "black",
            vjust = 1.4,
            size = 3) +
  facet_grid(participant ~ ., switch = "y") +
  theme_dark() +
  theme(panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(color = "grey40",
                                          size = 0.7)) +
  scale_color_manual(values = c(
    "black", "green", "red", "white", '#fef0d9','#fdd49e','#fdbb84','#fc8d59','#ef6548','#d7301f', 'grey25', 'grey40', 'grey55', 'grey70', 'grey85', "grey80"
  ) ) +
  scale_fill_manual(values = c(
    "#aaffaa", "white", "grey75", "#ffaaaa", "#cc8888"
  )) +
  scale_x_continuous(breaks = seq(0, 300, by = 10),
                     minor_breaks = seq(0, 300, by = 1),
                     expand = c(.01, 0)) +
                     #limits = c(0, 300)) +
  labs(x = "seconds",
       y = NULL)

N_subjects <- length(levels(d$participant_code))
ggsave("Liehse key logs.pdf", width = 50, height = N_subjects, units = "in", limitsize = FALSE)




