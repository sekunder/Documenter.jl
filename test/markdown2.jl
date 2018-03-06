import Documenter.Utilities: Markdown2
import Markdown


### ---------------------------------

md = Markdown.parse("""
    # Header

    Hello World _hehe foo bar **asd**_!!

    ![Image Title](https://image.com/asdfp.png "alt text")

    Foo Bar \\
    Baz

    - a __em__
    - b
    - c

    end

    ---

    ```language
    Hello
    > World!
    ```

    > Block
    > ``z+1``
    > Quote!
    >
    > ```math
    > x^2 + y^2 = z^2
    > ```

    --- ---

    A[^1] B[^fn]

    [^1]: Hello [World](https://google.com "link title")

    `code span`

    <a@b.com>

    !!! warn "HAHAHA"
        Hellow

        ``math
        x+1
        ``

    ---

    | Column One | Column Two | Column Three |
    |:---------- | ---------- |:------------:|
    | Row `1`    | Column `2` | > asd        |
    | *Row* 2    | **Row** 2  | Column ``3`` |

    """)

md2 = Markdown2.convert(md)
Markdown2.printmd2(md2)
