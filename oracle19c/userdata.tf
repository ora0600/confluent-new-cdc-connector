data "template_file" "oracle_instanceDB" {
  template = file("utils/instanceDB.sh")
}
