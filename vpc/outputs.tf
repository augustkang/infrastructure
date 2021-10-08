output "public_subnet" {
  description = "public subnet ids"
  value       = aws_subnet.public.*.id
}

output "public_subnet_cidr" {
  description = "public subnet cidr"
  value       = aws_subnet.public.*.cidr_block
}

output "private_subnet" {
  description = "private subnet ids"
  value       = aws_subnet.private.*.id
}

output "private_subnet_cidr" {
  description = "private subnet cidr"
  value       = aws_subnet.private.*.cidr_block
}

output "vpc_id" {
  description = "vpc id"
  value       = aws_vpc.this.id
}
