import os
import yaml
import tempfile
from pathlib import Path
from kubernetes import client, config
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def gen_client():
    kube_config_orig = f'{Path.home()}/.kube/config'
    tmp_config = tempfile.NamedTemporaryFile().name

    with open(kube_config_orig, "r") as fd:
        kubeconfig = yaml.load(fd, Loader=yaml.FullLoader)
    for cluster in kubeconfig["clusters"]:
        cluster["cluster"]["insecure-skip-tls-verify"] = True
    with open(tmp_config, "w") as fd:
        yaml.dump(kubeconfig, fd, default_flow_style=False)

    config.load_kube_config(tmp_config)
    os.remove(tmp_config)

    return client.CoreV1Api()


v1 = gen_client()
print(v1.list_namespace())
