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

struct List <: MarkdownBlockNode end

# Non-Commonmark extensions
struct DisplayMath <: MarkdownBlockNode
    formula :: String
end

struct Footnote <: MarkdownBlockNode
    id :: String
    nodes :: Vector{MarkdownBlockNode} # Footnote is a container block
end

struct Table <: MarkdownBlockNode end
struct Admonition <: MarkdownBlockNode end

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

struct Image <: MarkdownInlineNode end
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

# struct List <: MarkdownBlockNode end
#
# # Non-Commonmark extensions
# struct DisplayMath <: MarkdownBlockNode end
_convert_block(b::Markdown.LaTeX) = DisplayMath(b.formula)
# struct FootnoteDefinition <: MarkdownBlockNode end
_convert_block(b::Markdown.Footnote) = Footnote(b.id, _convert_block(b.text))
# struct Table <: MarkdownBlockNode end
# struct Admonition <: MarkdownBlockNode end




_convert_inline(xs::Vector) = MarkdownInlineNode[_convert_inline(x) for x in xs]
_convert_inline(s::String) = Text(s)
function _convert_inline(s::Markdown.Code)
    @assert isempty(s.language) # TODO: error
    CodeSpan(s.code)
end
_convert_inline(s::Markdown.Bold) = Strong(_convert_inline(s.text))
_convert_inline(s::Markdown.Italic) = Emphasis(_convert_inline(s.text))
_convert_inline(s::Markdown.Link) = Link(s.url, _convert_inline(s.text))

# struct Image <: MarkdownInlineNode end
# #struct InlineHTML <: MarkdownInlineNode end # the parser in Base does not support this currently
# struct LineBreak <: MarkdownInlineNode end
#
# # Non-Commonmark extensions
# struct InlineMath <: MarkdownInlineNode end
_convert_inline(s::Markdown.LaTeX) = InlineMath(s.formula)
# struct Footnote <: MarkdownInlineNode end
function _convert_inline(s::Markdown.Footnote)
    @assert s.text === nothing # footnote references should not have any content, TODO: error
    FootnoteReference(s.id)
end

end
