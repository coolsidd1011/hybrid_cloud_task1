
  
// TO SHOW OUR PROVIDER IS AWS


provider "aws" {
  region = "ap-south-1"
  profile = "default"
}


resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow TLS inbound traffic"


  ingress {
    description = "TCP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

// TO USE EC2  SERVICE
resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task1key"
  security_groups = [ "allow_ssh_http" ]




// TO CONNECT TO OS
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/task1key.pem")
    host     = aws_instance.web.public_ip
  }



// INSTALL REQ SOFTWARE
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "lwos1"
  }

}


// TO CREATE S3 BUCKET 
resource "aws_s3_bucket" "bs3" {
    bucket = "task1-bucket-1011"
    acl    = "public-read"
    tags = {
      Name = "file_stg"
      Environment = "Dev" 
    }
     versioning {
       enabled = true
     }

}


// TO UPLOAD IMAGE
resource "aws_s3_bucket_object" "object" {
  bucket = "task1-bucket-1011"
  key    = "download.jpg"
  source = "/download.jpg"
  content_type = "image or jpg"
  acl = "public-read"
  depends_on = [
       aws_s3_bucket.bs3

   ]
}

locals{
    s3_origin_id="s3-origin"
}


// TO MANAGE CLOUDFRONT 
resource "aws_cloudfront_distribution" "myCloudfront" {
    origin {
        domain_name = aws_s3_bucket.bs3.bucket_regional_domain_name
        origin_id   = local.s3_origin_id

        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id

        # Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
    
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }

    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}


// TO CREATE EBS STORAGE
resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}


// TO ATTACH STORAGE 

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/task1key.pem")
    host     = aws_instance.web.public_ip
  }

// TO MOUNT
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/coolsidd1011/hybrid_cloud_task1.git /var/www/html/"
    ]
  }
}



resource "null_resource" "nulllocal1"  {

// TO LAUNCH WEBPAGE USING CMD
depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "firefox  ${aws_instance.web.public_ip}"
  	}
}
