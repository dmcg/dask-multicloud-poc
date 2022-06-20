import os.path
from dask import annotate, delayed


def in_org(name):
    return annotate(resources={f'org-{name}': 1})


@delayed
def my_org():
    return os.environ['POOL_NAME']
