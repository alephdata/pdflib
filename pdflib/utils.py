from collections import defaultdict
from datetime import datetime
from lxml import etree

RDF_NS = '{http://www.w3.org/1999/02/22-rdf-syntax-ns#}'


def xmp_to_dict(xmp):
    """Parse an XMP string into a python dictionary."""
    tree = etree.fromstring(xmp)
    descriptions = tree.findall(RDF_NS+'Description')
    metadata = defaultdict(dict)
    if descriptions:
        for desc in descriptions:
            nsmap = {}
            for (key, val) in desc.nsmap.items():
                # Sometime there are duplicate None values, better check
                if not nsmap.get(val):
                    nsmap[val] = key
            for (key, val) in desc.attrib.items():
                ns, key = _parse_namespace(key)
                if val:
                    metadata[nsmap[ns]][key] = val
            for child in desc.getchildren():
                ns, key = _parse_namespace(child.tag)
                val = child.text
                if val and val.strip(' \n\t\r'):
                    metadata[nsmap[ns]][key] = val.strip(' \n\t\r')
    return metadata


def _parse_namespace(key):
    namespace = key.split("}")[0][1:]
    key = ''.join(key.split("}")[1:]).lower()
    return (namespace, key)


def parse_datestring(datestr):
    """coverts date strings in pdf metadata like `u'D:19861200000000'` to
    date objects"""
    return datetime.strptime(datestr[2:15], '%Y%m%d%H%M%S')


__all__ = [xmp_to_dict, parse_datestring]
