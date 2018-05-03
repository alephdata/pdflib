import os
import glob
import shutil

import pytest

from pdflib import Document


class TestPdflib(object):
    docs = [
        (b"tests/resources/c1_2572401.pdf", 3),
        (b"tests/resources/FAC.pdf", 4),
        (b"tests/resources/graph.pdf", 1),
    ]

    def _clean_images(self):
        shutil.rmtree('tests/images', ignore_errors=True)

    @pytest.mark.parametrize("path, no_imgs", docs)
    def test_extract_images(self, path, no_imgs):
        self._clean_images()
        doc = Document(path)
        doc.extract_images(path=b"tests/images", prefix=b"img")
        assert os.path.exists("tests/images")
        assert len(glob.glob(os.path.join("tests/images", "*.png"))) == no_imgs

    def test_extract_text(self):
        doc = Document(b"tests/resources/prop.pdf")
        text = ""
        for page in doc:
            text += ' \n'.join(page.lines).strip()
        assert "Milestones" in text

    def test_extract_metadata(self):
        doc = Document(b"tests/resources/FAC.pdf")
        assert doc.metadata
        assert doc.xmp_metadata
