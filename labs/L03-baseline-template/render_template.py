from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('.'))
template = env.get_template('baseline.j2')

router_vars = {
    "hostname": "Meridian-SW-02",
    "banner_message": "UNAUTHORIZED ACCESS PROHIBITED. Lab environment.",
    "domain_name": "meridian.local",
    "syslog_server": "10.0.7.50",
    "ntp_server": "10.0.8.60"
}

rendered_config = template.render(router_vars)

print(rendered_config)

with open("Meridian-RTR-01.cfg", "w") as f:
    f.write(rendered_config)
