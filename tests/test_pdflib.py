import os
import glob
import shutil

import pytest

from pdflib import Document


class TestPdflib(object):
    docs = [
        ("tests/resources/c1_2572401.pdf", 3),
        ("tests/resources/FAC.pdf", 4),
        ("tests/resources/graph.pdf", 1),
    ]

    def _clean_images(self):
        shutil.rmtree('tests/images', ignore_errors=True)

    @pytest.mark.parametrize("path, no_imgs", docs)
    def test_extract_images(self, path, no_imgs):
        self._clean_images()
        doc = Document(path)
        doc.extract_images(path="tests/images", prefix="img")
        assert os.path.exists("tests/images")
        assert len(glob.glob(os.path.join("tests/images", "*.png"))) == no_imgs

    def test_bytes_paths(self):
        self._clean_images()
        doc = Document(b"tests/resources/FAC.pdf")
        doc.extract_images(path=b"tests/images", prefix="img")
        assert os.path.exists("tests/images")
        assert len(glob.glob(os.path.join("tests/images", "*.png"))) == 4

    def test_extract_text(self):
        doc = Document("tests/resources/prop.pdf")
        text = ""
        for page in doc:
            text += ' \n'.join(page.lines).strip()
        assert "Milestones" in text

    def test_extract_metadata(self):
        doc = Document("tests/resources/FAC.pdf")
        assert doc.metadata
        assert doc.xmp_metadata

    def test_non_existent_file(self):
        with pytest.raises(IOError):
            Document("tests/resources/not-exists.pdf")

    def test_directory_path(self):
        with pytest.raises(IOError):
            Document("test/resources/")

    def test_non_pdf_file(self):
        with pytest.raises(IOError):
            Document("tests/resources/not-pdf.txt")

    def test_empty_pdf(self):
        with pytest.raises(IOError):
            Document("tests/resources/empty.pdf")

    def test_right_to_left(self):
        doc = Document("tests/resources/Fairy-Circles-Truly-a-Fairy-Tale-R-FKB-Kids-Stories_FA.pdf")
        text = ""
        for page in doc:
            text += ' \n'.join(page.lines).strip()

        with open("tests/resources/Fairy-Circles-Truly-a-Fairy-Tale-R-FKB-Kids-Stories_FA.txt", "r") as f:
            correct = f.read()
        assert correct == text