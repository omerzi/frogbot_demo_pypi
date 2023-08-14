import yaml

with open('example.yaml') as f:
    data = yaml.safe_load(f)
    print(data)
