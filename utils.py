from collections import defaultdict
from lxml import etree

RDF_NS = '{http://www.w3.org/1999/02/22-rdf-syntax-ns#}'


def xmp_to_dict(xmp):
    """Parse an XMP string into a python dictionary."""
    tree = etree.fromstring(xmp)
    descriptions = tree.findall(RDF_NS+'Description')
    metadata = defaultdict(list)
    if descriptions:
        for desc in descriptions:
            for (key, val) in desc.attrib.items():
                # strip namespace
                key = key.split("}")[-1].lower()
                if val and val not in metadata[key]:
                    metadata[key].append(val)
            for child in desc.getchildren():
                key = child.tag.split("}")[-1].lower()
                val = child.text
                if val and val not in metadata[key]:
                    val = val.strip(' \n\t\r')
                    if val:
                        metadata[key].append(val)
    return dict(metadata)