-- | This module provides a Heist frontend for the digestive-functors library.
--
-- Disclaimer: this documentation requires very basic familiarity with
-- digestive-functors. You might want to take a quick look at this tutorial
-- first:
--
-- <https://github.com/jaspervdj/digestive-functors/blob/master/examples/tutorial.lhs>
--
-- This module exports the functions 'digestiveSplices' and
-- 'bindDigestiveSplices', and most users will not require anything else.
--
-- These splices are used to create HTML for different form elements. This way,
-- the developer doesn't have to care about setting e.g. the previous values in
-- a text field when something goes wrong.
--
-- For documentation on the different splices, see the different functions
-- exported by this module. All splices have the same name as given in
-- 'digestiveSplices'.
{-# LANGUAGE OverloadedStrings #-}
module Text.Digestive.Heist
    ( -- * Core methods
      digestiveSplices
    , bindDigestiveSplices

      -- * Splices
    , dfInputText
    , dfInputTextArea
    , dfInputPassword
    , dfInputHidden
    , dfInputSelect
    , dfInputRadio
    , dfInputCheckbox
    , dfInputSubmit
    , dfLabel
    , dfForm
    , dfErrorList
    , dfChildErrorList
    , dfSubView
    ) where

import Control.Monad (liftM)
import Data.Maybe (fromMaybe)
import Data.Monoid (mappend)

import Data.Text (Text)
import Text.Digestive.View
import Text.Templating.Heist
import qualified Data.Text as T
import qualified Text.XmlHtml as X

bindDigestiveSplices :: Monad m => View Text -> HeistState m -> HeistState m
bindDigestiveSplices = bindSplices . digestiveSplices

digestiveSplices :: Monad m => View Text -> [(Text, Splice m)]
digestiveSplices view =
    [ ("dfInputText",      dfInputText view)
    , ("dfInputTextArea",  dfInputTextArea view)
    , ("dfInputPassword",  dfInputPassword view)
    , ("dfInputHidden",    dfInputHidden view)
    , ("dfInputSelect",    dfInputSelect view)
    , ("dfInputRadio",     dfInputRadio view)
    , ("dfInputCheckbox",  dfInputCheckbox view)
    , ("dfInputSubmit",    dfInputSubmit view)
    , ("dfLabel",          dfLabel view)
    , ("dfForm",           dfForm view)
    , ("dfErrorList",      dfErrorList view)
    , ("dfChildErrorList", dfChildErrorList view)
    , ("dfSubView",        dfSubView view)
    ]

attr :: Bool -> (Text, Text) -> [(Text, Text)] -> [(Text, Text)]
attr False _ = id
attr True  a = (a :)

makeElement :: Text -> [X.Node] -> [(Text, Text)] -> [X.Node]
makeElement name nodes = return . flip (X.Element name) nodes

getRefAttributes :: Monad m => HeistT m (Text, [(Text, Text)])
getRefAttributes = do
    node <- getParamNode
    return $ case node of
        X.Element _ as _ ->
            let ref = fromMaybe (error $ show node ++ ": missing ref") $
                        lookup "ref" as
            in (ref, filter ((/= "ref") . fst) as)
        _                -> (error "Wrong type of node!", [])

getContent :: Monad m => HeistT m [X.Node]
getContent = liftM X.childNodes getParamNode

dfInputText :: Monad m => View v -> Splice m
dfInputText view = do
    (ref, attrs) <- getRefAttributes
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $
        ("type", "text") : ("id", ref') :
        ("name", ref') : ("value", value) : attrs

dfInputTextArea :: Monad m => View v -> Splice m
dfInputTextArea view = do
    (ref, attrs) <- getRefAttributes
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "textarea" [X.TextNode value] $
        ("id", ref') : ("name", ref') : attrs

dfInputPassword :: Monad m => View v -> Splice m
dfInputPassword view = do
    (ref, attrs) <- getRefAttributes
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $
        ("type", "password") : ("id", ref') :
        ("name", ref') : ("value", value) : attrs

dfInputHidden :: Monad m => View v -> Splice m
dfInputHidden view = do
    (ref, attrs) <- getRefAttributes
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $
        ("type", "hidden") : ("id", ref') :
        ("name", ref') : ("value", value) : attrs

dfInputSelect :: Monad m => View Text -> Splice m
dfInputSelect view = do
    (ref, attrs) <- getRefAttributes
    let ref'           = absoluteRef ref view
        (choices, idx) = fieldInputChoice ref view
        children       = zipWith makeOption choices [0 ..]
        value i        = ref' `mappend` "." `mappend` T.pack (show i)
        makeOption c i = X.Element "option"
            (attr (idx == i) ("selected", "selected") [("value", value i)])
            [X.TextNode c]
    return $ makeElement "select" children $
        ("id", ref') : ("name", ref') : attrs

dfInputRadio :: Monad m => View Text -> Splice m
dfInputRadio view = do
    (ref, attrs) <- getRefAttributes

    let ref'           = absoluteRef ref view
        (choices, idx) = fieldInputChoice ref view

        children       = concat $ zipWith makeOption choices [0 ..]
        value i        = ref' `mappend` "." `mappend` T.pack (show i)
        makeOption c i =
            [ X.Element "input"
                (attr (idx == i) ("checked", "checked") $
                    ("type", "radio") : ("value", value i) :
                    ("id",    value i) : ("name", ref') :
                    attrs ) []
            , X.Element "label" [("for", value i)] [X.TextNode c]
            ]

    return children

dfInputCheckbox :: Monad m => View Text -> Splice m
dfInputCheckbox view = do
    (ref, attrs) <- getRefAttributes
    let ref'  = absoluteRef ref view
        value = fieldInputBool ref view
    return $ makeElement "input" [] $ attr value ("checked", "checked") $
        ("type", "checkbox") : ("id", ref') : ("name", ref') : attrs

dfInputSubmit :: Monad m => View v -> Splice m
dfInputSubmit _ = do
    (_, attrs) <- getRefAttributes
    return $ makeElement "input" [] $ ("type", "submit") : attrs

dfLabel :: Monad m => View v -> Splice m
dfLabel view = do
    (ref, attrs) <- getRefAttributes
    content      <- getContent
    let ref' = absoluteRef ref view
    return $ makeElement "label" content $ ("for", ref') : attrs

dfForm :: Monad m => View v -> Splice m
dfForm view = do
    (_, attrs) <- getRefAttributes
    content    <- getContent
    return $ makeElement "form" content $
        ("method", "POST") :
        ("enctype", T.pack (show $ viewEncType view)) :
        attrs

errorList :: [Text] -> [(Text, Text)] -> [X.Node]
errorList []   _     = []
errorList errs attrs = [X.Element "ul" attrs $ map makeError errs]
  where
    makeError e = X.Element "li" [] [X.TextNode e]

dfErrorList :: Monad m => View Text -> Splice m
dfErrorList view = do
    (ref, attrs) <- getRefAttributes
    return $ errorList (errors ref view) attrs

dfChildErrorList :: Monad m => View Text -> Splice m
dfChildErrorList view = do
    (ref, attrs) <- getRefAttributes
    return $ errorList (childErrors ref view) attrs

dfSubView :: Monad m => View Text -> Splice m
dfSubView view = do
    (ref, _) <- getRefAttributes
    content  <- getContent
    let view' = subView ref view
    nodes <- localTS (bindDigestiveSplices view') $ runNodeList content
    stopRecursion
    return nodes
