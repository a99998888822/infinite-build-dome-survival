"""Cutout regression: enclosed artwork must survive a matching background."""
import sys
import unittest
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from cavern_image_processing import remove_back


class ExteriorCutoutTests(unittest.TestCase):
    def test_enclosed_matching_colours_stay_opaque(self):
        for kind,background in [('solid',(64,64,64)),('checker',(64,64,64)),('magenta',(255,0,255))]:
            with self.subTest(kind=kind):
                a=np.full((64,64,4),255,dtype=np.uint8)
                a[:,:,:3]=background
                if kind=='checker':
                    y,x=np.mgrid[:64,:64]
                    a[((x//8+y//8)%2)==1,:3]=124
                a[15:49,15:49,:3]=(25,16,35)
                a[19:45,19:45,:3]=background
                result=np.array(remove_back(Image.fromarray(a),kind))
                self.assertEqual(int(result[0,0,3]),0)
                self.assertTrue(np.all(result[19:45,19:45,3]==255))
                np.testing.assert_array_equal(result[:,:,:3],a[:,:,:3])

    def test_gray_rock_touching_edge_does_not_seed_checker_cut(self):
        y,x=np.mgrid[:64,:64]
        a=np.full((64,64,4),255,dtype=np.uint8)
        a[:,:,:3]=np.where(((x//8+y//8)%2)[:,:,None],124,64)
        a[16:48,:32,:3]=(25,16,35)
        a[20:44,:28,:3]=(69,69,75)
        result=np.array(remove_back(Image.fromarray(a),'checker'))
        self.assertTrue(np.all(result[20:44,:28,3]==255))
        self.assertEqual(int(result[0,0,3]),0)

    def test_reviewed_hole_does_not_open_other_matching_regions(self):
        a=np.full((64,64,4),255,dtype=np.uint8)
        a[:,:,:3]=(255,0,255)
        a[8:56,8:56,:3]=(25,16,35)
        a[12:24,12:24,:3]=(255,0,255)
        a[32:48,32:48,:3]=(255,0,255)
        result=np.array(remove_back(Image.fromarray(a),'magenta',[(16,16)]))
        self.assertTrue(np.all(result[12:24,12:24,3]==0))
        self.assertTrue(np.all(result[32:48,32:48,3]==255))


if __name__=='__main__': unittest.main()
