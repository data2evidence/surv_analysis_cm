library(boot) 
library(table1)
melanoma2 <- melanoma
 
# Factor the basic variables that
# we're interested in
# melanoma2$status <- 
#   factor(melanoma2$status, 
#          levels=c(2,1,3),
#          labels=c("Alive", # Reference
#                   "Melanoma death", 
#                   "Non-melanoma death"))

print(typeof(melanoma2))
print(class(melanoma2))
print(head(melanoma2))
t1 <- table1(~ factor(sex) + age + factor(ulcer) + thickness | age, data=melanoma2)
htmltools::save_html(t1, file = "table1_melanoma.html")