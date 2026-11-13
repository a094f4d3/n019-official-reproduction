from __future__ import annotations

import tempfile
import unittest
from argparse import Namespace
from pathlib import Path

from n019.assemble_paper_metrics import assemble


class AssemblePaperMetricsTests(unittest.TestCase):
    def write(self, root: Path, name: str, payload: str) -> str:
        path = root / name
        path.write_text(payload, encoding="utf-8")
        return str(path)

    def test_collects_only_present_metrics(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            evpc = self.write(
                root,
                "evpc.json",
                '{"paper_conditions":{"I":{"mean_eer_percent":47.1},'
                '"L":{"mean_eer_percent":47.8}},'
                '"wer_percent":{"anon":7.2}}',
            )
            wnt = self.write(
                root,
                "wnt.json",
                '{"attacks":{"I":{"mean_eer_percent":40.1},'
                '"L":{"mean_eer_percent":42.2}}}',
            )
            utmos = self.write(root, "utmos.json", '{"mean":3.5}')
            args = Namespace(
                system="DU-pred-nt",
                evpc=evpc,
                s_eval=None,
                wnt_summary=wnt,
                wer_json=evpc,
                wer_condition="anon",
                utmos=utmos,
                whisqa=None,
            )
            result = assemble(args)
        self.assertEqual(
            result["values"],
            {
                "E-VPC I": 47.1,
                "E-VPC L": 47.8,
                "W-NT I": 40.1,
                "W-NT L": 42.2,
                "WER": 7.2,
                "UTMOS": 3.5,
            },
        )
        self.assertEqual(
            result["missing"],
            ["E-VPC S", "W-NT S", "WhiSQA"],
        )

    def test_s_metrics_require_the_retrained_model_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            s_eval = self.write(
                root,
                "s.json",
                '{"paper_conditions":{"S":{"mean_eer_percent":35.2}}}',
            )
            args = Namespace(
                system="DU-pred-nt",
                evpc=None,
                s_eval=s_eval,
                wnt_summary=None,
                wer_json=None,
                wer_condition="anon",
                utmos=None,
                whisqa=None,
            )
            result = assemble(args)
        self.assertEqual(result["values"], {"E-VPC S": 35.2})
        self.assertNotIn("E-VPC I", result["values"])

    def test_standalone_wer_report_uses_scalar_percent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wer = self.write(root, "wer.json", '{"wer_percent":6.25}')
            args = Namespace(
                system="DU-pred-nt",
                evpc=None,
                s_eval=None,
                wnt_summary=None,
                wer_json=wer,
                wer_condition="anon",
                utmos=None,
                whisqa=None,
            )
            result = assemble(args)
        self.assertEqual(result["values"], {"WER": 6.25})


if __name__ == "__main__":
    unittest.main()
