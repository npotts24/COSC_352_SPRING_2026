library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)

# ── 1. Scrape ────────────────────────────────────────────────────────────────
url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
tables <- read_html(url) %>% html_nodes("table") %>% html_table(fill = TRUE)

if (length(tables) == 0) stop("No tables scraped — check network access or URL")

# ── 2. Clean ─────────────────────────────────────────────────────────────────
raw_data <- tables[[1]][, 1:7]                                   # FIX 1: trim first
colnames(raw_data) <- c("index", "date", "name", "age", "address", "method", "notes")

cleaned_data <- raw_data %>%
    filter(!is.na(method), method != "method") %>%
    mutate(
        method_group = case_when(
            str_detect(method, regex("Shoot|Gun|Firearm|Gunshot",  ignore_case = TRUE)) ~ "Shooting",
            str_detect(method, regex("Stab|Knife|Sharp|Cut",       ignore_case = TRUE)) ~ "Stabbing",
            str_detect(method, regex("Blunt|Beating|Bludgeon|Club",ignore_case = TRUE)) ~ "Blunt Force",
            str_detect(method, regex("Strang|Asphyx|Choke",        ignore_case = TRUE)) ~ "Strangulation",
            str_detect(method, regex("Trauma|Assault|Force",       ignore_case = TRUE)) ~ "Other Violence",
            TRUE ~ "Other/Unknown"
        ),
        method_group = factor(method_group, levels = c(            # FIX 2: correct case
            "Shooting", "Other/Unknown", "Stabbing", "Other Violence", "Blunt Force"
        ))
    )

# ── 3. Plot ──────────────────────────────────────────────────────────────────
method_plot <- ggplot(cleaned_data, aes(x = method_group, fill = method_group)) +
    geom_bar() +
    geom_text(stat = "count", aes(label = after_stat(count)), vjust = -0.5, size = 3.5) +
    scale_fill_brewer(palette = "Set2") +
    labs(
        title    = "Homicide Methods In Baltimore (2025)",
        subtitle = "Analysis of reported methods of homicides in the Baltimore region",
        x = "Method of Incident",
        y = "Number of Victims"
    ) +
    theme_minimal() +
    theme(legend.position = "none")

ggsave("/output/method_histogram.png", plot = method_plot)

# ── 4. Summary table ─────────────────────────────────────────────────────────
cat("\n--- Tabular Frequency Table: Homicide Methods ---\n")
cleaned_data %>%
    count(method_group, name = "count") %>%
    arrange(desc(count)) %>%
    as.data.frame() %>%
    print()