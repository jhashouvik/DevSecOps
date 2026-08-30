variable "amiid" {
  default = "ami-07a00cf47dbbc844c"
}

variable "type" {
  default = "t2.micro"
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
