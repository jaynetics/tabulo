require "spec_helper"

describe Tabulo::Cell do
  let(:cell) do
    described_class.new(
      alignment: :right,
      cell_data: cell_data,
      formatter: formatter,
      left_padding: left_padding,
      padding_character: " ",
      right_padding: right_padding,
      styler: styler,
      truncation_indicator: ".",
      value: value,
      width: width)
  end

  let(:formatter) { -> (source) { source.to_s } }
  let(:row_index) { 5 }
  let(:column_index) { 3 }
  let(:left_padding) { 2 }
  let(:right_padding) { 3 }
  let(:source) { "hi" }
  let(:styler) { -> (source, str) { str } }
  let(:value) { 30 }
  let(:width) { 6 }
  let(:cell_data) { Tabulo::CellData.new(source, row_index, column_index) }

  describe "#height" do
    subject { cell.height }
    before { allow(cell).to receive(:subcells).and_return(["a", "b", "c"]) }

    it "returns the number of subcells in the cell" do
      is_expected.to eq(3)
    end
  end

  describe "#padded_truncated_subcells" do
    subject { cell.padded_truncated_subcells(target_height) }
    let(:value) { "ab\ncde\nfg" }

    context "when the target height is greater than required to contain the wrapped cell content" do
      let(:target_height) { 5 }

      it "returns an array of strings each representing the part of the cell occurring on a different line, "\
        "plus a number of blank lines to bring the total up the the target height, with total width equal to "\
        "cell width plus the specified amount of extra padding on either side" do
        is_expected.to eq(
          [
            "      ab   ",
            "     cde   ",
            "      fg   ",
            "           ",
            "           ",
          ])
      end
    end

    context "when the target height is just enough to contain the wrapped cell content" do
      let(:target_height) { 3 }

      it "returns an array of strings each representing the part of the cell occurring on a different line, "\
        "with total width equal to cell width plus the specified amount of extra padding on either side" do
        is_expected.to eq(
          [
            "      ab   ",
            "     cde   ",
            "      fg   ",
          ])
      end
    end

    context "when the target height is less than required to contain the wrapped cell content" do
      let(:target_height) { 2 }

      it "returns an array of strings each representing the part of the cell occurring on a different line, "\
        "truncated to the target height, with total width equal to cell width plus the specified amount of "\
        "extra padding on either side" do
        is_expected.to eq(
          [
            "      ab   ",
            "     cde.  ",
          ])
      end
    end
  end

  describe "#formatted_content" do
    subject { cell.formatted_content }
    let(:formatter) { -> (n) { "%.3f" % n } }
    let(:width) { 4 }
    let(:styler) { -> (source, str) { "some styling #{str}" } }

    it "returns the result of calling the Cell's formatter on its value, without applying styler or wrapping" do
      is_expected.to eq("30.000")
    end
  end
end
