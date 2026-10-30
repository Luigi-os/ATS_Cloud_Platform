# Dedicated to basic or local/random resources of the project that do not directly fall into individual functional modules. 

# Random suffix for unique resource names.
resource "random_id" "suffix" {
  byte_length = 4   
  
}