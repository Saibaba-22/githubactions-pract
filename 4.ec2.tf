# EC2 App Server (FINAL FIXED)
resource "aws_instance" "app" {
  ami                    = "ami-05d2d839d4f73aafb"
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = "ec2-key"

  tags = {
    Name = var.ec2_name
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("ec2-key.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "mkdir -p /home/ubuntu/student-python",
      "mkdir -p /home/ubuntu/student-python/templates",
      "sudo chown -R ubuntu:ubuntu /home/ubuntu/student-python"
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/index.html.tpl", {
      ec2_ip = self.public_ip    
      } 
    )
    destination = "/home/ubuntu/student-python/templates/index.html"
  }

  provisioner "file" {
    source      = "./Student-python/app.py"
    destination = "/home/ubuntu/student-python/app.py"
  }

  provisioner "file" {
    source      = "./Student-python/config.py"
    destination = "/home/ubuntu/student-python/config.py"
  }

  provisioner "file" {
    source      = "./Student-python/requirements.txt"
    destination = "//home/ubuntu/student-python/requirements.txt"
  }

# Inside execute 
  provisioner "remote-exec" {
    inline = [
      "set -e",

      # Install dependencies
      "sudo apt update -y",
      "sudo apt install -y python3 python3-pip python3-venv mysql-client libmysqlclient-dev",

      # Install python pip packages
      "cd /home/ubuntu/student-python &&  python3 -m venv venv &&  venv/bin/pip install --upgrade pip && venv/bin/pip install flask flask_sqlalchemy pymysql gunicorn",

      # Check Versions
      "venv/bin/pip list | grep -E 'Flask|SQLAlchemy|PyMySQL|gunicorn'",

      # Connnection for Database server and run app
      "cd /home/ubuntu/student-python &&  DB_HOST=${aws_db_instance.db.address}  DB_PORT=3306  DB_NAME=${var.db_name}  DB_USER=${var.db_user}  DB_PASSWORD=${var.db_password}  nohup venv/bin/python app.py > app.log 2>&1 &",

      # Debug
      "sleep 5",
      "cat /home/ubuntu/student-python/app.log || true",
      "ps -ef | grep '[a]pp.py' || true"
      ]
    }
}
