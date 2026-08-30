output "vpc_id" {
  # Changed from .main to .my_vpc
  value = aws_vpc.my_vpc.id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "private_route_table_id" {
  # Added [0] because the resource uses 'count'
  value = length(aws_route_table.private) > 0 ? aws_route_table.private[0].id : null
}

