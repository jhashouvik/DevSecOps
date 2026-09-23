variable "amiid" {
  default = "ami-01a00762f46d584a1"
}

variable "type" {
  default = "t2.large"
}

variable "pemfile" { 
  default = "wezva2026"
}

variable "volsize" {
  type = number
  default = 8
}

variable "servername" {
  default = "demoserver"
}
