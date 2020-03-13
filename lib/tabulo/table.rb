require "tty-screen"
require "unicode/display_width"

module Tabulo

  # Represents a table primarily intended for "pretty-printing" in a fixed-width font.
  #
  # A Table is also an Enumerable, of which each element is a {Row}.
  class Table
    include Enumerable

    # @!visibility public
    DEFAULT_BORDER = :ascii

    # @!visibility public
    DEFAULT_COLUMN_WIDTH = 12

    # @!visibility public
    DEFAULT_COLUMN_PADDING = 1

    # @!visibility public
    DEFAULT_TRUNCATION_INDICATOR = "~"

    # @!visibility private
    PADDING_CHARACTER = " "

    # @!visibility private
    attr_reader :column_registry

    # @return [Enumerable] the underlying enumerable from which the table derives its data
    attr_accessor :sources

    # @param [Enumerable] sources the underlying Enumerable from which the table will derive its data
    # @param [Array[Symbol]] columns Specifies the initial columns. The Symbols provided must
    #   be unique. Each element of the Array  will be used to create a column whose content is
    #   created by calling the corresponding method on each element of sources. Note
    #   the {#add_column} method is a much more flexible way to set up columns on the table.
    # @param [:left, :right, :center, :auto] align_body (:auto) Determines the alignment of body cell
    #   (i.e. non-header) content within columns in this Table. Can be overridden for individual columns
    #   using the <tt>align_body</tt> option passed to {#add_column}. If passed <tt>:auto</tt>,
    #   alignment is determined by cell content, with numbers aligned right, booleans
    #   center-aligned, and other values left-aligned.
    # @param [:left, :right, :center] align_header (:center) Determines the alignment of header text
    #   for columns in this Table. Can be overridden for individual columns using the
    #   <tt>align_header</tt> option passed to {#add_column}
    # @param [:ascii, :markdown, :modern, :blank, nil] border (nil) Determines the characters used
    #   for the Table border, including both the characters around the outside of table, and the lines drawn
    #   within the table to separate columns from each other and the header row from the Table body.
    #   If <tt>nil</tt>, then the value of {DEFAULT_BORDER} will be used.
    #   Possible values are:
    #   - `:ascii`          Uses ASCII characters only
    #   - `:markdown`       Produces a GitHub-flavoured Markdown table
    #   - `:modern`         Uses non-ASCII Unicode characters to render a border with smooth continuous lines
    #   - `:blank`          No border characters are rendered
    #   - `:reduced_ascii`  Like `:ascii`, but without left or right borders, and with internal vertical
    #                       borders and intersection characters consisting of whitespace only
    #   - `:reduced_modern` Like `:modern`, but without left or right borders, and with internal vertical
    #                       borders and intersection characters consisting of whitespace only
    #   - `:classic`        Like `:ascii`, but does not have a horizontal line at the bottom of the
    #                       table. This reproduces the default behaviour in `tabulo` v1.
    # @param [nil, #to_proc] border_styler (nil) A lambda or other callable object taking
    #   a single parameter, representing a section of the table's borders (which for this purpose
    #   include any horizontal and vertical lines inside the table), and returning a string.
    #   If passed <tt>nil</tt>, then no additional styling will be applied to borders. If passed a
    #   callable, then that callable will be called for each border section, with the
    #   resulting string rendered in place of that border. The extra width of the string returned by the
    #   {border_styler} is not taken into consideration by the internal table rendering calculations
    #   Thus it can be used to apply ANSI escape codes to border characters, to colour the borders
    #   for example, without breaking the table formatting.
    # @param [nil, Integer, Array] column_padding (1) Determines the amount of blank space with which to pad
    #   either side of each column. If passed an Integer, then the given amount of padding is
    #   applied to each side of each column. If passed a two-element Array, then the first element of the
    #   Array indicates the amount of padding to apply to the left of each column, and the second
    #   element indicates the amount to apply to the right.
    # @param [Integer, nil] column_width The default column width for columns in this
    #   table, not excluding padding. If <tt>nil</tt>, then {DEFAULT_COLUMN_WIDTH} will be used.
    # @param [nil, #to_proc] formatter (:to_s.to_proc) The default formatter for columns in this
    #   table. See `formatter` option of {#add_column} for details.
    # @param [:start, nil, Integer] header_frequency (:start) Controls the display of column headers.
    #   If passed <tt>:start</tt>, headers will be shown at the top of the table only. If passed <tt>nil</tt>,
    #   headers will not be shown. If passed an Integer N (> 0), headers will be shown at the top of the table,
    #   then repeated every N rows.
    # @param [nil, #to_proc] header_styler (nil) The default header styler for columns in this
    #   table. See `header_styler` option of {#add_column} for details.
    # @param [nil, Integer] row_divider_frequency (nil) Controls the display of horizontal row dividers within
    #   the table body. If passed <tt>nil</tt>, dividers will not be shown. If passed an Integer N (> 0),
    #   dividers will be shown after every N rows. The characters used to form the dividers are
    #   determined by the `border` option, and are the same as those used to form the bottom edge of the
    #   header row.
    # @param [nil, #to_proc] styler (nil) The default styler for columns in this table. See `styler`
    #   option of {#add_column} for details.
    # @param [nil, String] truncation_indicator Determines the character used to indicate that a
    #   cell's content has been truncated. If omitted or passed <tt>nil</tt>,
    #   defaults to {DEFAULT_TRUNCATION_INDICATOR}. If passed something other than <tt>nil</tt> or
    #   a single-character String, raises {InvalidTruncationIndicatorError}.
    # @param [nil, Integer] wrap_body_cells_to Controls wrapping behaviour for table cells (excluding
    #   headers), if their content is longer than the column's fixed width. If passed <tt>nil</tt>, content will
    #   be wrapped for as many rows as required to accommodate it. If passed an Integer N (> 0), content will be
    #   wrapped up to N rows and then truncated thereafter.
    #   headers), if their content is longer than the column's fixed width. If passed <tt>nil</tt>, content will
    #   be wrapped for as many rows as required to accommodate it. If passed an Integer N (> 0), content will be
    #   wrapped up to N rows and then truncated thereafter.
    # @param [nil, Integer] wrap_header_cells_to Controls wrapping behaviour for header
    #   cells if the content thereof is longer than the column's fixed width. If passed <tt>nil</tt> (default),
    #   content will be wrapped for as many rows as required to accommodate it. If passed an Integer N (> 0),
    #   content will be wrapped up to N rows and then truncated thereafter.
    # @return [Table] a new {Table}
    # @raise [InvalidColumnLabelError] if non-unique Symbols are provided to columns.
    # @raise [InvalidBorderError] if invalid option passed to `border` parameter.
    def initialize(sources, *columns, align_body: :auto, align_header: :center, border: nil,
      border_styler: nil, column_padding: nil, column_width: nil, formatter: :to_s.to_proc,
      header_frequency: :start, header_styler: nil, row_divider_frequency: nil, styler: nil,
      truncation_indicator: nil, wrap_body_cells_to: nil, wrap_header_cells_to: nil)

      @sources = sources

      @align_body = align_body
      @align_header = align_header
      @border = (border || DEFAULT_BORDER)
      @border_styler = border_styler
      @border_instance = Border.from(@border, @border_styler)
      @column_padding = (column_padding || DEFAULT_COLUMN_PADDING)

      @left_column_padding, @right_column_padding =
        Array === @column_padding ? @column_padding : [@column_padding, @column_padding]

      @column_width = (column_width || DEFAULT_COLUMN_WIDTH)
      @formatter = formatter
      @header_frequency = header_frequency
      @header_styler = header_styler
      @row_divider_frequency = row_divider_frequency
      @styler = styler
      @truncation_indicator = validate_character(truncation_indicator,
        DEFAULT_TRUNCATION_INDICATOR, InvalidTruncationIndicatorError, "truncation indicator")
      @wrap_body_cells_to = wrap_body_cells_to
      @wrap_header_cells_to = wrap_header_cells_to

      @column_registry = { }
      columns.each { |item| add_column(item) }

      yield self if block_given?
    end

    # Adds a column to the Table.
    #
    # @param [Symbol, String, Integer] label A unique identifier for this column, which by
    #   default will also be used as the column header text (see also the header param). If the
    #   extractor argument is not also provided, then the label argument should correspond to
    #   a method to be called on each item in the table sources to provide the content
    #   for this column. If a String is passed as the label, then it will be converted to
    #   a Symbol for the purpose of serving as this label.
    # @param [:left, :center, :right, :auto, nil] align_body (nil) Specifies how the cell body contents
    #   should be aligned. If <tt>nil</tt> is passed, then the alignment is determined
    #   by the Table-level setting passed to the <tt>align_body</tt> option on Table initialization
    #   (which itself defaults to <tt>:auto</tt>). Otherwise this option determines the alignment of
    #   this column. If <tt>:auto</tt> is passed, the alignment is determined by the type of the cell
    #   value, with numbers aligned right, booleans center-aligned, and other values left-aligned.
    #   Note header text alignment is configured separately using the :align_header param.
    # @param [:left, :center, :right, nil] align_header (nil) Specifies how the header text
    #   should be aligned. If <tt>nil</tt> is passed, then the alignment is determined
    #   by the Table-level setting passed to the <tt>align_header</tt> (which itself defaults
    #   to <tt>:center</tt>). Otherwise, this option determines the alignment of the header
    #   content for this column.
    # @param [Symbol, String, Integer, nil] before (nil) The label of the column before (i.e. to
    #   the left of) which the new column should inserted. If <tt>nil</tt> is passed, it will be
    #   inserted after all other columns. If there is no column with the given label, then an
    #   {InvalidColumnLabelError} will be raised. A non-Integer labelled column can be identified
    #   in either String or Symbol form for this purpose.
    # @param [#to_proc] formatter (nil) A lambda or other callable object that
    #   will be passed the calculated value of each cell to determine how it should be displayed. This
    #   is distinct from the extractor (see below). For example, if the extractor for this column
    #   generates a Date, then the formatter might format that Date in a particular way.
    #   If no formatter is provided, then the callable that was passed to the `formatter` option
    #   of the table itself on its creation (see {#initialize}) (which itself defaults to
    #   `:to_s.to_proc`), will be used as the formatter for the column.
    # @param [nil, #to_s] header (nil) Text to be displayed in the column header. If passed nil,
    #   the column's label will also be used as its header text.
    # @param [nil, #to_proc] header_styler (nil) A lambda or other callable object taking
    #   a single parameter, representing a single line of within the header content for
    #   this column. For example, if the header cell content is wrapped over three lines, then
    #   the {header_styler} will be called once for each line. If passed <tt>nil</tt>, then
    #   no additional styling will be applied to the header cell content. If passed a callable,
    #   then that callable will be called for each line of content within the header cell, and the
    #   resulting string rendered in place of that line. The extra width of the string returned by the
    #   {header_styler} is not taken into consideration by the internal table and
    #   cell width calculations involved in rendering the table. Thus it can be used to apply
    #   ANSI escape codes to header cell content, to colour the cell content for example, without
    #   breaking the table formatting.
    #   Note that if the header content is truncated, then any {header_styler} will be applied to the
    #   truncation indicator character as well as to the truncated content.
    # @param [nil, #to_proc] styler (nil) A lambda or other callable object that will be passed
    #   two arguments: the calculated value of the cell (prior to the {formatter} being applied);
    #   and a string representing a single formatted line within the cell. For example, if the
    #   cell content is wrapped over three lines, then for that cell, the {styler} will be called
    #   three times, once for each line of content within the cell. If passed <tt>nil</tt>, then
    #   no additional styling will be applied to the cell content (other than what was already
    #   applied by the {formatter}). If passed a callable, then that callable will be called for
    #   each line of content within the cell, and the resulting string rendered in place of that
    #   line. The {styler} option differs from the {formatter} option in that the extra width of the
    #   string returned by {styler} is not taken into consideration by the internal table and
    #   cell width calculations involved in rendering the table. Thus it can be used to apply
    #   ANSI escape codes to cell content, to colour the cell content for example, without
    #   breaking the table formatting.
    #   Note that if the content of a cell is truncated, then the whatever styling is applied by the
    #   {styler} to the cell content will also be applied to the truncation indicator character.
    # @param [Integer] width (nil) Specifies the width of the column, excluding padding. If
    #   nil, then the column will take the width provided by the `column_width` param
    #   with which the Table was initialized.
    # @param [#to_proc] extractor A block or other callable
    #   that will be passed each of the Table sources to determine the value in each cell of this
    #   column. If this is not provided, then the column label will be treated as a method to be
    #   called on each source item to determine each cell's value.
    # @raise [InvalidColumnLabelError] if label has already been used for another column in this
    #   Table. (This is case-sensitive, but is insensitive to whether a String or Symbol is passed
    #   to the label parameter.)
    def add_column(label, align_body: nil, align_header: nil, before: nil, formatter: nil,
      header: nil, header_styler: nil, styler: nil, width: nil, &extractor)

      column_label = normalize_column_label(label)

      if column_registry.include?(column_label)
        raise InvalidColumnLabelError, "Column label already used in this table."
      end

      column = Column.new(
        align_body: align_body || @align_body,
        align_header: align_header || @align_header,
        extractor: extractor || label.to_proc,
        formatter: formatter || @formatter,
        header: (header || label).to_s,
        header_styler: header_styler || @header_styler,
        padding_character: PADDING_CHARACTER,
        styler: styler || @styler,
        truncation_indicator: @truncation_indicator,
        width: width || @column_width,
      )

      if before == nil
        add_column_final(column, column_label)
      else
        add_column_before(column, column_label, before)
      end
    end

    # Removes the column identifed by the passed label.
    #
    # @example
    #   table = Table.new(1..10, :itself, :even?, :odd?)
    #   table.add_column(:even2, header: "even?") { |n| n.even? }
    #   table.remove_column(:even2)
    #   table.remove_column(:odd?)
    #
    # @param [Symbol, String, Integer] label The unique identifier for the column to be removed,
    #   corresponding to the label that was passed as the first parameter to {#add_column} (or was
    #   used in the table initializer) when the column was originally added. For columns that were
    #   originally added with a String or Symbol label, either a String or Symbol form of that label
    #   can be passed to {#remove_column}, indifferently. For example, if the label passed to
    #   {#add_column} had been `"height"`, then that column could be removed by passing either
    #   `"height"` or `:height` to {#remove_column}. (However, if an Integer was originally passed
    #   as the label to {#add_column}, then only that same Integer, as an Integer, can be passed to
    #   {#remove_column} to remove that column.)
    # @return [true, false] If the label identifies a column in the table, then the column will be
    #   removed and true will be returned; otherwise no column will be removed, and false will be returned.
    def remove_column(label)
      !!column_registry.delete(Integer === label ? label : label.to_sym)
    end

    # @return [String] a graphical "ASCII" representation of the Table, suitable for
    #   display in a fixed-width font.
    def to_s
      if column_registry.any?
        bottom_edge = horizontal_rule(:bottom)
        rows = map(&:to_s)
        bottom_edge.empty? ? join_lines(rows) : join_lines(rows + [bottom_edge])
      else
        ""
      end
    end

    # Calls the given block once for each {Row} in the Table, passing that {Row} as parameter.
    #
    # @example
    #   table.each do |row|
    #     puts row
    #   end
    #
    # Note that when printed, the first row will visually include the headers (assuming these
    # were not disabled when the Table was initialized).
    def each
      @sources.each_with_index do |source, index|
        header =
          if (index == 0) && @header_frequency
            :top
          elsif (Integer === @header_frequency) && Util.divides?(@header_frequency, index)
            :middle
          end

        show_divider = @row_divider_frequency && (index != 0) && Util.divides?(@row_divider_frequency, index)

        yield Row.new(self, source, header: header, divider: show_divider)
      end
    end

    # @return [String] an "ASCII" graphical representation of the Table column headers.
    def formatted_header
      cells = get_columns.map(&:header_cell)
      format_row(cells, @wrap_header_cells_to)
    end

    # @param [:top, :middle, :bottom] align_body (:bottom) Specifies the position
    #   for which the resulting horizontal dividing line is intended to be printed.
    #   This determines the border characters that are used to construct the line.
    # @return [String] an "ASCII" graphical representation of a horizontal
    #   dividing line suitable for printing at the top, bottom or middle of the
    #   table.
    # @example Print a horizontal divider between each pair of rows, and again
    #   at the bottom:
    #
    #   table.each_with_index do |row, i|
    #     puts table.horizontal_rule(:middle) unless i == 0
    #     puts row
    #   end
    #   puts table.horizontal_rule(:bottom)
    #
    # It may be that `:top`, `:middle` and `:bottom` all look the same. Whether
    # this is the case depends on the characters used for the table border.
    def horizontal_rule(position = :bottom)
      column_widths = get_columns.map { |column| column.width + total_column_padding }
      @border_instance.horizontal_rule(column_widths, position)
    end

    # Reset all the column widths so that each column is *just* wide enough to accommodate
    # its header text as well as the formatted content of each its cells for the entire
    # collection, together with a single character of padding on either side of the column,
    # without any wrapping.
    #
    # Note that calling this method will cause the entire source Enumerable to
    # be traversed and all the column extractors and formatters to be applied in order
    # to calculate the required widths.
    #
    # Note also that this method causes column widths to be fixed as appropriate to the
    # formatted cell contents given the state of the source Enumerable at the point it
    # is called. If the source Enumerable changes between that point, and the point when
    # the Table is printed, then columns will *not* be resized yet again on printing.
    #
    # @param [nil, Numeric] max_table_width (:auto) With no args, or if passed <tt>:auto</tt>,
    #   stops the total table width (including padding and borders) from expanding beyond the
    #   bounds of the terminal screen.
    #   If passed <tt>nil</tt>, the table width will not be capped.
    #   Width is deducted from columns if required to achieve this, with one character progressively
    #   deducted from the width of the widest column until the target is reached. When the
    #   table is printed, wrapping or truncation will then occur in these columns as required
    #   (depending on how they were configured).
    #   Note that regardless of the value passed to max_table_width, the table will always be left wide
    #   enough to accommodate at least 1 character's width of content, 1 character of left padding and
    #   1 character of right padding in each column, together with border characters (1 on each side
    #   of the table and 1 between adjacent columns). I.e. there is a certain width below width the
    #   Table will refuse to shrink itself.
    # @return [Table] the Table itself
    def pack(max_table_width: :auto)
      get_columns.each { |column| column.width = wrapped_width(column.header) }

      @sources.each do |source|
        get_columns.each do |column|
          cell_width = wrapped_width(column.body_cell(source).formatted_content)
          column.width = Util.max(column.width, cell_width)
        end
      end

      if max_table_width
        shrink_to(max_table_width == :auto ? TTY::Screen.width : max_table_width)
      end

      self
    end

    # Creates a new {Table} from the current Table, transposed, that is rotated 90 degrees,
    # relative to the current Table, so that the header names of the current Table form the
    # content of left-most column of the new Table, and each column thereafter corresponds to one of the
    # elements of the current Table's <tt>sources</tt>, with the header of that column being the String
    # value of that element.
    #
    # @example
    #   puts Tabulo::Table.new(-1..1, :even?, :odd?, :abs).transpose
    #     # => +-------+--------------+--------------+--------------+
    #     #    |       |      -1      |       0      |       1      |
    #     #    +-------+--------------+--------------+--------------+
    #     #    | even? |     false    |     true     |     false    |
    #     #    |  odd? |     true     |     false    |     true     |
    #     #    |   abs |            1 |            0 |            1 |
    #
    # @param [Hash] opts Options for configuring the new, transposed {Table}.
    #   The following options are the same as the keyword params for the {#initialize} method for
    #   {Table}: <tt>column_width</tt>, <tt>column_padding</tt>, <tt>formatter</tt>,
    #   <tt>header_frequency</tt>, <tt>row_divider_frequency</tt>, <tt>wrap_header_cells_to</tt>,
    #   <tt>wrap_body_cells_to</tt>, <tt>border</tt>, <tt>border_styler</tt>, <tt>truncation_indicator</tt>,
    #   <tt>align_header</tt>, <tt>align_body</tt>.
    #   These are applied in the same way as documented for {#initialize}, when
    #   creating the new, transposed Table. Any options not specified explicitly in the call to {#transpose}
    #   will inherit their values from the original {Table} (with the exception of settings
    #   for the left-most column, containing the field names, which are determined as described
    #   below). In addition, the following options also apply to {#transpose}:
    # @option opts [nil, Integer] :field_names_width Determines the width of the left-most column of the
    #   new Table, which contains the names of "fields" (corresponding to the original Table's
    #   column headings). If this is not provided, then by default this column will be made just
    #   wide enough to accommodate its contents.
    # @option opts [String] :field_names_header ("") By default the left-most column will have a
    #   blank header; but this can be overridden by passing a String to this option.
    # @option opts [:left, :center, :right] :field_names_header_alignment (:right) Specifies how the
    #   header text of the left-most column (if it has header text) should be aligned.
    # @option opts [:left, :center, :right] :field_names_body_alignment (:right) Specifies how the
    #   body text of the left-most column should be aligned.
    # @option opts [#to_proc] :headers (:to_s.to_proc) A lambda or other callable object that
    #   will be passed in turn each of the elements of the current Table's <tt>sources</tt>
    #   Enumerable, to determine the text to be displayed in the header of each column of the
    #   new Table (other than the left-most column's header, which is determined as described
    #   above).
    # @return [Table] a new {Table}
    # @raise [InvalidBorderError] if invalid argument passed to `border` parameter.
    def transpose(opts = {})
      default_opts = [:align_body, :align_header, :border, :border_styler, :column_padding, :column_width,
        :formatter, :header_frequency, :row_divider_frequency, :truncation_indicator, :wrap_body_cells_to,
        :wrap_header_cells_to].map do |sym|
        [sym, instance_variable_get("@#{sym}")]
      end.to_h

      initializer_opts = default_opts.merge(Util.slice_hash(opts, *default_opts.keys))
      default_extra_opts = { field_names_body_alignment: :right, field_names_header: "",
        field_names_header_alignment: :right, field_names_width: nil, headers: :to_s.to_proc }
      extra_opts = default_extra_opts.merge(Util.slice_hash(opts, *default_extra_opts.keys))

      # The underlying enumerable for the new table, is the columns of the original table.
      fields = column_registry.values

      Table.new(fields, **initializer_opts) do |t|

        # Left hand column of new table, containing field names
        width_opt = extra_opts[:field_names_width]
        field_names_width = (width_opt.nil? ? fields.map { |f| f.header.length }.max : width_opt)

        t.add_column(:dummy, align_body: extra_opts[:field_names_body_alignment],
          align_header: extra_opts[:field_names_header_alignment], header: extra_opts[:field_names_header],
          width: field_names_width, &:header)

        # Add a column to the new table for each of the original table's sources
        sources.each_with_index do |source, i|
          t.add_column(i, header: extra_opts[:headers].call(source)) do |original_column|
            original_column.body_cell_value(source)
          end
        end
      end
    end

    # @!visibility private
    def formatted_body_row(source, header:, divider:)
      cells = get_columns.map { |column| column.body_cell(source) }
      inner = format_row(cells, @wrap_body_cells_to)

      if header == :top
        join_lines([
          horizontal_rule(:top),
          formatted_header,
          horizontal_rule(:middle),
          inner
        ].reject(&:empty?))
      elsif header
        join_lines([
          horizontal_rule(:middle),
          formatted_header,
          horizontal_rule(:middle),
          inner
        ].reject(&:empty?))
      elsif divider
        join_lines([
          horizontal_rule(:middle),
          inner
        ].reject(&:empty?))
      else
        inner
      end
    end

    private

    # @!visibility private
    def get_columns
      column_registry.values
    end

    # @!visibility private
    def add_column_before(column, label, before)
      old_column_entries = @column_registry.to_a
      new_column_entries = []

      old_column_entries.each do |entry|
        new_column_entries << [label, column] if entry[0] == before
        new_column_entries << entry
      end

      found = (new_column_entries.size == old_column_entries.size + 1)
      raise InvalidColumnLabelError, "There is no column with label #{before}" unless found

      @column_registry = new_column_entries.to_h
    end

    # @!visibility private
    def add_column_final(column, label)
      @column_registry[label] = column
    end

    # @!visibility private
    def normalize_column_label(label)
      case label
      when Integer, Symbol
        label
      when String
        label.to_sym
      end
    end

    # @!visibility private
    def shrink_to(max_table_width)
      columns = get_columns
      num_columns = columns.count
      total_columns_width = columns.inject(0) { |sum, column| sum + column.width }
      total_padding = num_columns * total_column_padding
      total_borders = num_columns + 1
      unadjusted_table_width = total_columns_width + total_padding + total_borders

      # Ensure max table width is at least wide enough to accommodate table borders and padding
      # and one character of content.
      min_table_width = total_padding + total_borders + column_registry.count
      max_table_width = Util.max(min_table_width, max_table_width)
      required_reduction = Util.max(unadjusted_table_width - max_table_width, 0)

      required_reduction.times do
        widest_column = columns.inject(columns.first) do |widest, column|
          column.width >= widest.width ? column : widest
        end

        widest_column.width -= 1
      end
    end

    # @!visibility private
    def total_column_padding
      @left_column_padding + @right_column_padding
    end

    # @!visibility private
    #
    # Formats a single header row or body row as a String.
    #
    # @param [String[][]] cells an Array of Array-of-Strings, each of which represents a
    #   "stack" of "subcells". Each such stack represents the wrapped content of a given
    #   "cell" in this row, from the top down, one String for each "line".
    #   Each String includes the spaces, if any, on either side required for the
    #   "internal padding" of the cell to carry out the cell content alignment -- but
    #   does not include the single character of padding around each column.
    # @param [Integer] wrap_cells_to the number of "lines" of wrapped content to allow
    #   before truncating.
    # @return [String] the entire formatted row including all padding and borders.
    def format_row(cells, wrap_cells_to)
      max_cell_height = cells.map(&:height).max
      row_height = ([wrap_cells_to, max_cell_height].compact.min || 1)
      subcell_stacks = cells.map do |cell|
        cell.padded_truncated_subcells(row_height, @left_column_padding, @right_column_padding)
      end
      subrows = subcell_stacks.transpose.map do |subrow_components|
        @border_instance.join_cell_contents(subrow_components)
      end

      join_lines(subrows)
    end

    # @!visibility private
    def join_lines(lines)
      lines.join($/)  # join strings with cross-platform newline
    end

    # @!visibility private
    def validate_character(character, default, exception_class, message_fragment)
      case (c = (character || default))
      when nil
        ; # do nothing
      when String
        if Unicode::DisplayWidth.of(c) != 1
          raise exception_class, "#{message_fragment} is neither nil nor a single-character String"
        end
      else
        raise exception_class, "#{message_fragment} is neither nil nor a single-character String"
      end
      c
    end

    # @!visibility private
    # @return [Integer] the length of the longest segment of str when split by newlines
    def wrapped_width(str)
      segments = str.split($/)
      segments.inject(1) do |longest_length_so_far, segment|
        Util.max(longest_length_so_far, Unicode::DisplayWidth.of(segment))
      end
    end
  end
end
