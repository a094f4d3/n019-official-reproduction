from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from n019.parse_vpc_results import paper_conditions, parse_vpc_results


RESULTS = """\
---- Time: 03-11-26_03:59 ----

---- ASV_eval^anon results ----
  dataset split gender enrollment     trial    EER
0   libri  test      f     original  original  4.600
3   libri  test      m     original  original  0.400
1   libri  test      f     original     anon  49.200
4   libri  test      m     original     anon  48.800
0   libri  test      f       anon      anon  47.600
3   libri  test      m       anon      anon  47.200

---- ASR results ----
  dataset split    asr    WER
0   libri  test    anon  7.410
"""


class ParseVpcResultsTests(unittest.TestCase):
    def test_parses_aa_eer_and_wer(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "results.txt"
            path.write_text(RESULTS, encoding="utf-8")
            parsed = parse_vpc_results(path)
            self.assertAlmostEqual(
                parsed["asv"]["AA"]["mean_eer_percent"],
                47.4,
            )
            self.assertEqual(parsed["asv"]["AA"]["female_eer_percent"], 47.6)
            self.assertEqual(parsed["wer_percent"]["anon"], 7.41)
            self.assertAlmostEqual(
                parsed["asv"]["OA"]["mean_eer_percent"],
                49.0,
            )
            self.assertEqual(parsed["timestamp"], "03-11-26_03:59")

    def test_incomplete_asv_mode_is_not_invented(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "results.txt"
            path.write_text(RESULTS, encoding="utf-8")
            parsed = parse_vpc_results(path)
            self.assertNotIn("I", parsed["asv"])
            self.assertNotIn("L", parsed["asv"])
            self.assertNotIn("S", parsed["asv"])

    def test_paper_condition_mapping_depends_on_model_role(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "results.txt"
            path.write_text(RESULTS, encoding="utf-8")
            parsed = parse_vpc_results(path)
            original = paper_conditions(parsed["asv"], "original")
            anonymised = paper_conditions(parsed["asv"], "anon")
            self.assertEqual(set(original), {"OO", "I", "L"})
            self.assertEqual(set(anonymised), {"S"})
            self.assertAlmostEqual(original["I"]["mean_eer_percent"], 49.0)
            self.assertAlmostEqual(original["L"]["mean_eer_percent"], 47.4)
            self.assertAlmostEqual(anonymised["S"]["mean_eer_percent"], 47.4)

    def test_csv_restores_scenarios_missing_from_txt_summary(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            text_path = root / "results_orig.txt"
            text_path.write_text(RESULTS, encoding="utf-8")
            csv_path = root / "results_n019.csv"
            csv_path.write_text(
                ",dataset,split,gender,enrollment,trial,EER\n"
                "0,libri,test,f,original,original,8.761\n"
                "1,libri,test,f,original,anon,44.525\n"
                "2,libri,test,f,anon,anon,46.754\n"
                "3,libri,test,m,original,original,0.418\n"
                "4,libri,test,m,original,anon,49.222\n"
                "5,libri,test,m,anon,anon,46.092\n",
                encoding="utf-8",
            )
            parsed = parse_vpc_results(text_path, results_csv=csv_path)
            paper = paper_conditions(parsed["asv"], "original")
            self.assertAlmostEqual(paper["I"]["mean_eer_percent"], 46.8735)
            self.assertAlmostEqual(paper["L"]["mean_eer_percent"], 46.423)


if __name__ == "__main__":
    unittest.main()
