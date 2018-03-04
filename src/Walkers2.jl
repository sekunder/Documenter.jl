"""
Provides the [`walk`](@ref) function.
"""
module Walkers2

import ..Documenter:
    Utilities

using Compat, DocStringExtensions
import Compat: Markdown

"""
$(SIGNATURES)

Calls `f(meta, parent, element)` on `element` and any of its child elements. `meta` is a
`Dict{Symbol,Any}` containing metadata such as current module.
"""
walk(f, element) = _walk(f, Dict{Symbol,Any}(), nothing, element)

function _walk(f, meta, parent, block::Vector)
    for each in block
        _walk(f, meta, parent, each)
    end
end

const MDContentElements = Union{
    Markdown.MD,
    Markdown.BlockQuote,
    Markdown.Paragraph,
    Markdown.MD,
    Markdown.Admonition,
}
function walk(f, meta, parent, element::MDContentElements)
    f(meta, parent, element)
    _walk(f, meta, element, element.content)
end

const MDTextElements = Union{
    Markdown.Bold,
    Markdown.Header,
    Markdown.Italic,
    Markdown.Footnote,
    Markdown.Link,
}
function _walk(f, meta, parent, element::MDTextElements)
    f(meta, parent, element)
    _walk(f, meta, element, element.text)
end

function _walk(f, meta, parent, element::Markdown.Image)
    f(meta, parent, element)
    _walk(f, meta, element, element.alt)
end

function _walk(f, meta, parent, element::Markdown.Table)
    f(meta, parent, element)
    _walk(f, meta, element, element.rows)
end

function _walk(f, meta, parent, element::Markdown.List)
    f(meta, parent, element)
    _walk(f, meta, element, element.items)
end

function _walk(f, meta, parent, element)
    f(meta, parent, element)
    nothing
end

end
