module Elm.Parser.Util exposing (asPointer, commentSequence, exactIndentWhitespace, moreThanIndentWhitespace, multiLineCommentWithTrailingSpaces, trimmed, unstrictIndentWhitespace)

import Combine exposing ((*>), (<$), (<$>), (<*), Parser, choice, lookAhead, many, many1, maybe, or, regex, withState)
import Elm.Parser.Comments exposing (multilineComment, singleLineComment)
import Elm.Parser.Ranges exposing (withRange)
import Elm.Parser.State exposing (State, currentIndent)
import Elm.Parser.Whitespace exposing (many1Spaces, manySpaces, nSpaces, realNewLine)
import Elm.Syntax.Base exposing (VariablePointer)


asPointer : Parser State String -> Parser State VariablePointer
asPointer p =
    withRange (VariablePointer <$> p)


unstrictIndentWhitespace : Parser State (List String)
unstrictIndentWhitespace =
    many1 (manySpaces <* maybe someComment <* newLineWithSomeIndent)


exactIndentWhitespace : Parser State ()
exactIndentWhitespace =
    withState
        (\state ->
            choice
                [ () <$ (regex ("( *\\n)+ {" ++ toString (currentIndent state) ++ "}") <* lookAhead (regex "[a-zA-Z0-9\\(\\+/*\\|\\>]"))
                , () <$ many1 (manySpaces *> maybe someComment *> newLineWithIndentExact state)
                ]
        )


multiLineCommentWithTrailingSpaces : Parser State ()
multiLineCommentWithTrailingSpaces =
    multilineComment <* manySpaces


someComment : Parser State ()
someComment =
    or singleLineComment
        multiLineCommentWithTrailingSpaces


commentSequence : Parser State ()
commentSequence =
    ()
        <$ many
            (or someComment
                (realNewLine *> manySpaces *> someComment)
            )


trimmed : Parser State x -> Parser State x
trimmed x =
    maybe moreThanIndentWhitespace *> x <* maybe moreThanIndentWhitespace


moreThanIndentWhitespace : Parser State ()
moreThanIndentWhitespace =
    withState
        (\state ->
            choice
                [ ()
                    <$ (regex ("(( *\\n)+ {" ++ toString (currentIndent state) ++ "} +| +)")
                            <* lookAhead (regex "[a-zA-Z0-9\\(\\+/*\\|\\>]")
                       )
                , ()
                    <$ many1
                        (manySpaces
                            *> commentSequence
                            *> newLineWithIndentPlus state
                        )
                , () <$ many1Spaces <* maybe someComment
                ]
        )


newLineWithSomeIndent : Parser State (List String)
newLineWithSomeIndent =
    many1 (realNewLine <* manySpaces)


newLineWithIndentExact : State -> Parser State String
newLineWithIndentExact state =
    realNewLine
        *> many (manySpaces *> realNewLine)
        *> nSpaces (currentIndent state)


newLineWithIndentPlus : State -> Parser State (List String)
newLineWithIndentPlus state =
    many1
        (realNewLine
            *> many (manySpaces *> realNewLine)
            *> nSpaces (currentIndent state)
            *> many1Spaces
        )
