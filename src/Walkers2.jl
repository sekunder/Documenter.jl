"""
Provides the [`walk`](@ref) function.
"""
module Walkers2

import ..Documenter:
    Utilities,
    Utilities.Markdown2

using Compat, DocStringExtensions
using Compat.Markdown

@enum MDNodeClass block inline

"""
$(SIGNATURES)

Calls `f(meta, parent, element)` on `element` and any of its child elements. `meta` is a
`Dict{Symbol,Any}` containing metadata such as current module.
"""
walk(f, element::Markdown.MD) = _walk_block(f, Dict{Symbol,Any}(), element.content)

function _walk_block(f, meta, xs::Vector)
    for x in xs
        _walk_block(f, meta, x)
    end
end

function _walk_block(f, meta, b::Union{Markdown.BlockQuote, Markdown.Admonition})
    f(block, b) || return
    _walk_block(f, meta, b.content)
end

_walk_block(f, meta, b::Markdown.Paragraph) = f(block, b) ? _walk_inline(f, meta, b.content) : nothing
_walk_block(f, meta, b::Markdown.Footnote) = f(block, b) ? _walk_block(f, meta, b.text) : nothing
_walk_block(f, meta, b::Markdown.Header) = f(block, b) ? _walk_inline(f, meta, b.text) : nothing


function _walk_block(f, meta, b::Markdown.List)
    f(block, b) || return
    for item in b.items
        _walk_block.(f, meta, b.items)
    end
end

function _walk_block(f, meta, b::Markdown.Table)
    f(block, b) || return
    for row in b.rows, cell in row
        _walk_inline(f, meta, cell)
    end
end

#_walk_block(f, meta, b::Union{Markdown.HorizontalRule, Markdown.Code, Markdown.LaTeX}) = (f(block, b); nothing)
_walk_block(f, meta, b) = (f(block, b); nothing)

# Non-Commonmark extensions


function _walk_inline(f, meta, xs::Vector)
    for x in xs
        _walk_inline(f, meta, x)
    end
end

const MDInlineTextElements = Union{
    Markdown.Bold,
    Markdown.Italic,
    Markdown.Link,
}
_walk_inline(f, meta, s::MDInlineTextElements) = f(inline, s) ? _walk_inline(f, meta, s.text) : nothing

_walk_inline(f, meta, s) = (f(inline, s); nothing)

end
