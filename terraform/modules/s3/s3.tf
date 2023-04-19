variable "stack_name" {
  type = string
  default = "terraform"
}

resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "${replace(var.stack_name, "/[^a-z0-9.]+/", "-")}-"

  tags = {
    Name = "${var.stack_name}_s3"
  }
}