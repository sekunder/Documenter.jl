module Markdown2

using Compat
import Compat.Markdown

# Contains all the types for the Markdown AST tree
abstract type MarkdownNode end
abstract type MarkdownBlockNode <: MarkdownNode end
abstract type MarkdownInlineNode <: MarkdownNode end

"""
    MD

A type to represent Markdown documents.
"""
struct MD
    nodes :: Vector{MarkdownBlockNode}

    MD(content::AbstractVector) = new(content)
end

# Forward some array methods
Base.push!(md::MD, x) = push!(md.content, x)
Base.getindex(md::MD, args...) = md.content[args...]
Base.setindex!(md::MD, args...) = setindex!(md.content, args...)
Base.endof(md::MD) = endof(md.content)
Base.length(md::MD) = length(md.content)
Base.isempty(md::MD) = isempty(md.content)


# Block nodes
# ===========

struct ThematicBreak <: MarkdownBlockNode end

struct Heading <: MarkdownBlockNode
    level :: Int
    nodes :: Vector{MarkdownInlineNode}

    function Heading(level::Integer, nodes::Vector{MarkdownInlineNode})
        @assert 1 <= level <= 6 # TODO: error message
        new(level, nodes)
    end
end

struct CodeBlock <: MarkdownBlockNode
    language :: String
    code :: String
end

#struct HTMLBlock <: MarkdownBlockNode end # the parser in Base does not support this currently
#struct LinkDefinition <: MarkdownBlockNode end # the parser in Base does not support this currently

"""
"""
struct Paragraph <: MarkdownBlockNode
    nodes :: Vector{MarkdownInlineNode}
end

## Container blocks
struct BlockQuote <: MarkdownBlockNode
    nodes :: Vector{MarkdownBlockNode}
end

"""
If `.orderedstart` is `nothing` then the list is unordered. Otherwise is specifies the first
number in the list.
"""
struct List <: MarkdownBlockNode
    tight :: Bool
    orderedstart :: Union{Int, Nothing}
    items :: Vector{Vector{MarkdownBlockNode}} # TODO: Better types?
end

# Non-Commonmark extensions
struct DisplayMath <: MarkdownBlockNode
    formula :: String
end

struct Footnote <: MarkdownBlockNode
    id :: String
    nodes :: Vector{MarkdownBlockNode} # Footnote is a container block
end

struct Table <: MarkdownBlockNode
    align :: Vector{Symbol}
    cells :: Array{Vector{MarkdownInlineNode}, 2} # TODO: better type?
    # Note: Table is _not_ a container type -- the cells can only contan inlines.
end

struct Admonition <: MarkdownBlockNode
    category :: String
    title :: String
    nodes :: Vector{MarkdownBlockNode} # Admonition is a container block
end

# Inline nodes
# ============

struct Text <: MarkdownInlineNode
    text :: String
end

struct CodeSpan <: MarkdownInlineNode
    code :: String
end

struct Emphasis <: MarkdownInlineNode
    nodes :: Vector{MarkdownInlineNode}
end

struct Strong <: MarkdownInlineNode
    nodes :: Vector{MarkdownInlineNode}
end

struct Link <: MarkdownInlineNode
    destination :: String
    #title :: String # the parser in Base does not support this currently
    nodes :: Vector{MarkdownInlineNode}
end

struct Image <: MarkdownInlineNode
    destination :: String
    description :: String
    #title :: String # the parser in Base does not support this currently
    #nodes :: Vector{MarkdownInlineNode} # the parser in Base does not parse the description currently
end
#struct InlineHTML <: MarkdownInlineNode end # the parser in Base does not support this currently
struct LineBreak <: MarkdownInlineNode end

# Non-Commonmark extensions
struct InlineMath <: MarkdownInlineNode
    formula :: String
end

struct FootnoteReference <: MarkdownInlineNode
    id :: String
end


# Conversion methods
# ==================

function convert(md::Markdown.MD)
    nodes = map(_convert_block, md.content)
    MD(nodes)
end

_convert_block(xs::Vector) = MarkdownBlockNode[_convert_block(x) for x in xs]
_convert_block(b::Markdown.HorizontalRule) = ThematicBreak()
_convert_block(b::Markdown.Header{N}) where N = Heading(N, _convert_inline(b.text))
_convert_block(b::Markdown.Code) = CodeBlock(b.language, b.code)
_convert_block(b::Markdown.Paragraph) = Paragraph(_convert_inline(b.content))
_convert_block(b::Markdown.BlockQuote) = BlockQuote(_convert_block(b.content))
function _convert_block(b::Markdown.List)
    tight = all(equalto(1), length.(b.items))
    orderedstart = (b.ordered == -1) ? nothing : b.ordered
    List(tight, orderedstart, _convert_block.(b.items))
end

# Non-Commonmark extensions
_convert_block(b::Markdown.LaTeX) = DisplayMath(b.formula)
_convert_block(b::Markdown.Footnote) = Footnote(b.id, _convert_block(b.text))
function _convert_block(b::Markdown.Table)
    @assert all(equalto(length(b.align)), length.(b.rows)) # TODO: error
    cells = [_convert_inline(b.rows[i][j]) for i = 1:length(b.rows), j = 1:length(b.align)]
    @show typeof(cells)
    Table(
        b.align,
        [_convert_inline(b.rows[i][j]) for i = 1:length(b.rows), j = 1:length(b.align)]
    )
end
_convert_block(b::Markdown.Admonition) = Admonition(b.category, b.title, _convert_block(b.content))


_convert_inline(xs::Vector) = MarkdownInlineNode[_convert_inline(x) for x in xs]
_convert_inline(s::String) = Text(s)
function _convert_inline(s::Markdown.Code)
    @assert isempty(s.language) # TODO: error
    CodeSpan(s.code)
end
_convert_inline(s::Markdown.Bold) = Strong(_convert_inline(s.text))
_convert_inline(s::Markdown.Italic) = Emphasis(_convert_inline(s.text))
_convert_inline(s::Markdown.Link) = Link(s.url, _convert_inline(s.text))
_convert_inline(s::Markdown.Image) = Image(s.url, s.alt)
# struct InlineHTML <: MarkdownInlineNode end # the parser in Base does not support this currently
_convert_inline(::Markdown.LineBreak) = LineBreak()

# Non-Commonmark extensions
_convert_inline(s::Markdown.LaTeX) = InlineMath(s.formula)
function _convert_inline(s::Markdown.Footnote)
    @assert s.text === nothing # footnote references should not have any content, TODO: error
    FootnoteReference(s.id)
end


# printmd2
const INDENT = ".   "

printmd2(xs :: Markdown2.MD) = printmd2(xs.nodes)

function printmd2(xs :: Vector; indent=0)
    for x in xs
        printmd2(x; indent = indent)
    end
end

function printmd2(x::T; indent=0) where T <: Markdown2.MarkdownNode
    if :nodes in fieldnames(T)
        print(INDENT^indent)
        print(typeof(x))

        print(" : ")
        for field in fieldnames(T)
            field == :nodes && continue
            print("$field='$(getfield(x, field))' ")
        end

        println()
        printmd2(x.nodes; indent = indent + 1)
    else
        print(INDENT^indent)
        print(x)
        println()
    end
end

function printmd2(x::Markdown2.List; indent=0)
    print(INDENT^indent)
    print(typeof(x))

    print(" : ")
    for field in fieldnames(Markdown2.List)
        field == :items && continue
        print("$field='$(getfield(x, field))' ")
    end

    println()
    printmd2(x.items; indent = indent + 1)
end

function printmd2(x::Markdown2.Table; indent=0)
    print(INDENT^indent)
    print(typeof(x))

    print(" : ")
    for field in fieldnames(Markdown2.Table)
        field == :cells && continue
        print("$field='$(getfield(x, field))' ")
    end

    println()

    for i = 1:size(x.cells, 1), j = 1:size(x.cells, 1)
        print(INDENT^(indent+1))
        println("cell $i - $j")
        printmd2(x.cells[i,j]; indent = indent + 2)
    end
end

end
