variable "amiid" {
  default = "ami-01a00762f46d584a1"
}

variable "type" {
  default = "t2.large"
}

variable "ssh_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "pemfile" { 
  default = "wezva2026"
}

variable "volsize" {
  type = number
  default = 30
}

variable "servername" {
  default = "demoserver"
}
