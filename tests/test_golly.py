import golly_python.pylife
import unittest

class GollyPythonTest(unittest.TestCase):
    """
    """
    @classmethod
    def setUpClass(self):
        pass

    @classmethod
    def tearDownClass(self):
        """
        """
        pass

    def test_routes_index(self):
        """
        """
        gol = golly_python.pylife.GOL(
            s1 = '[{"30":[50,51,54,55,56]},{"31":[53]},{"32":[51]}]',
            s2 = '[{"90":[25]},{"91":[27]},{"92":[24,25,28,29,30]}]',
            rows = 120,
            columns = 100
        )
        for i in range(10):
            live_counts = gol.next_step()

        from pprint import pprint
        pprint(gol.get_live_counts())
