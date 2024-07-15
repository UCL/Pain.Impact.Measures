#Recoding and renaming UKB data
#Charlotte Woolley

#Load tidyverse
library(tidyverse)

#Data needed
dat <- read.csv("all_data_participant.csv", na.strings = c(""," ", "NA")) 

# Uses the codings and data dictionary files from the UKB website -
# see https://biobank.ndph.ox.ac.uk/showcase/index.cgi
codes_dict <- read_csv("Codings.csv", na = c(""," ")) 
data_dict <- read_tsv("Data_Dictionary_Showcase.tsv", na = c(""," ")) 

#Function that finds the data codes needed for the selected Biobank data field/column, 
#gets the data field and transforms this into long format, replaces the old data 
#codes with new codes and transforms field back into wide format 
replace_codes <- function(column) {
  
  col_name <- as.character(substitute(column))
  
  #data codes needed for the selected Biobank data field
  codes_needed <- full_join(codes_dict, data_dict) %>%
    select(FieldID, Meaning, Value)  %>%
    mutate(FieldID = paste("X", FieldID, ".0.0", sep = "")) %>%
    filter(FieldID == col_name) %>%
    pivot_wider(names_from = FieldID, values_from = Value)
  
  #Get the data field and transform this into long format
  data_needed <- dat %>%
    select(eid, {{ column }}) %>%
    separate_longer_delim(cols = {{ column }}, delim = "|") %>%
    mutate({{ column }} := as.character({{ column }})) 
  
  #Replace the data with new codes and transform back into wide format, 
  #then transform again into single column
  recoded_data <- full_join(codes_needed, data_needed) %>%
    drop_na(eid) %>%
    group_by(eid) %>%
    summarise(sum_eid = sum(eid), 
              Meaning = paste0(Meaning, collapse = "|"),
              {{ column }} := paste0({{ column }}, collapse = "|")) %>%
    ungroup() %>%
    arrange(eid) %>%
    mutate({{ column }} := case_when(Meaning == "NA" ~ {{ column }},
                                     TRUE ~ Meaning)) %>%
    select({{ column }}) %>%
    unlist()
  
  return(recoded_data)
}

##Run the function on every data field and test it actually works
dat2 <- dat %>%
  arrange(eid) %>%
  mutate(across(starts_with("X"), replace_codes))

#Check numbers in categories are the same (This prints each column name and checks
#the same counts within groups for each field are the same in the orginal coded and new coded data field)
for (i in colnames(dat)){
  val <- dat %>% count(get(i)) %>% select(n) %>% arrange(n) == dat2 %>% count(get(i)) %>% select(n) %>% arrange(n)
  print(i)
  res <- all(val == TRUE)
  print(res)
}

## Rename the columns
dat3 <- dat2
orderings <- data.frame(FieldID = colnames(dat3)) %>%
  mutate(order1 = 1:nrow(.),
         order2 = replace_na(as.numeric(str_remove_all(FieldID, "\\.0.0|eid|X")),12))

field_ids_names <- data_dict %>%
  select(FieldID, Field) %>%
  mutate(FieldID = paste("X", FieldID, ".0.0", sep = "")) %>%
  filter(FieldID %in% colnames(dat3)) %>%
  mutate(Field = str_replace_all(Field, " |\\/|\\(|\\)|\\-", "_"),
         Field = str_replace_all(Field, "___|__", "_"),
         Field = str_remove_all(Field, "\\.|\\,|\\_$"),
         Field = str_replace_all(Field, "\\+", "plus")) %>%
  full_join(orderings) %>%
  mutate(Field = case_when(FieldID == "eid" ~ "eid", TRUE ~ Field)) %>%
  arrange(order1)

colnames(dat3) <- field_ids_names$Field

write_csv(dat3, "all_data_RENAMED_RECODED.csv")
write_csv(field_ids_names %>% select(FieldID, Field), "field_IDs_names.csv")

