--------------------------------------------------------------------------------
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
--
-- You can give arbitrary attributes to most of the elements (i.e. where it
-- makes sense). This means you can do e.g.:
--
-- > <dfInputTextArea ref="description" cols="20" rows="3" />
{-# LANGUAGE OverloadedStrings #-}
module Text.Digestive.Heist
    ( -- * Core methods
      digestiveSplices
    , bindDigestiveSplices

      -- * Main splices
    , dfInput
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

      -- * Utility splices
    , dfIfChildErrors
    ) where


--------------------------------------------------------------------------------
import           Control.Monad         (liftM, mplus)
import           Data.Function         (on)
import           Data.List             (unionBy)
import           Data.Maybe            (fromMaybe)
import           Data.Monoid           (mappend)
import           Data.Text             (Text)
import qualified Data.Text             as T
import           Text.Templating.Heist
import qualified Text.XmlHtml          as X


--------------------------------------------------------------------------------
import           Text.Digestive.View


--------------------------------------------------------------------------------
bindDigestiveSplices :: Monad m => View Text -> HeistState m -> HeistState m
bindDigestiveSplices = bindSplices . digestiveSplices


--------------------------------------------------------------------------------
digestiveSplices :: Monad m => View Text -> [(Text, Splice m)]
digestiveSplices view =
    [ ("dfInput",          dfInput view)
    , ("dfInputText",      dfInputText view)
    , ("dfInputTextArea",  dfInputTextArea view)
    , ("dfInputPassword",  dfInputPassword view)
    , ("dfInputHidden",    dfInputHidden view)
    , ("dfInputSelect",    dfInputSelect view)
    , ("dfInputRadio",     dfInputRadio view)
    , ("dfInputCheckbox",  dfInputCheckbox view)
    , ("dfInputFile",      dfInputFile view)
    , ("dfInputSubmit",    dfInputSubmit view)
    , ("dfLabel",          dfLabel view)
    , ("dfForm",           dfForm view)
    , ("dfErrorList",      dfErrorList view)
    , ("dfChildErrorList", dfChildErrorList view)
    , ("dfSubView",        dfSubView view)
    , ("dfIfChildErrors",  dfIfChildErrors view)
    ]


--------------------------------------------------------------------------------
attr :: Bool -> (Text, Text) -> [(Text, Text)] -> [(Text, Text)]
attr False _ = id
attr True  a = (a :)


--------------------------------------------------------------------------------
makeElement :: Text -> [X.Node] -> [(Text, Text)] -> [X.Node]
makeElement name nodes = return . flip (X.Element name) nodes


--------------------------------------------------------------------------------
getRefAttributes :: Monad m
                 => Maybe Text                       -- ^ Optional default ref
                 -> HeistT m (Text, [(Text, Text)])  -- ^ (Ref, other attrs)
getRefAttributes defaultRef = do
    node <- getParamNode
    return $ case node of
        X.Element _ as _ ->
            let ref = fromMaybe (error $ show node ++ ": missing ref") $
                        lookup "ref" as `mplus` defaultRef
            in (ref, filter ((/= "ref") . fst) as)
        _                -> (error "Wrong type of node!", [])


--------------------------------------------------------------------------------
getContent :: Monad m => HeistT m [X.Node]
getContent = liftM X.childNodes getParamNode


--------------------------------------------------------------------------------
-- | Does not override existing attributes
addAttrs :: [(Text, Text)]  -- ^ Original attributes
         -> [(Text, Text)]  -- ^ Attributes to add
         -> [(Text, Text)]  -- ^ Resulting attributes
addAttrs = unionBy (on (==) fst)


--------------------------------------------------------------------------------
-- | Generate an input field with a supplied type. Example:
--
-- > <dfInput type="date" ref="date" />
dfInput :: Monad m => View v -> Splice m
dfInput view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $ addAttrs attrs
        [("id", ref'), ("name", ref'), ("value", value)]


--------------------------------------------------------------------------------
-- | Generate a text input field. Example:
--
-- > <dfInputText ref="user.name" />
dfInputText :: Monad m => View v -> Splice m
dfInputText view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $ addAttrs attrs
        [("type", "text"), ("id", ref'), ("name", ref'), ("value", value)]


--------------------------------------------------------------------------------
-- | Generate a text area. Example:
--
-- > <dfInputTextArea ref="user.about" />
dfInputTextArea :: Monad m => View v -> Splice m
dfInputTextArea view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "textarea" [X.TextNode value] $ addAttrs attrs
        [("id", ref'), ("name", ref')]


--------------------------------------------------------------------------------
-- | Generate a password field. Example:
--
-- > <dfInputPassword ref="user.password" />
dfInputPassword :: Monad m => View v -> Splice m
dfInputPassword view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $ addAttrs attrs
        [("type", "password"), ("id", ref'), ("name", ref'), ("value", value)]


--------------------------------------------------------------------------------
-- | Generate a hidden input field. Example:
--
-- > <dfInputHidden ref="user.forgery" />
dfInputHidden :: Monad m => View v -> Splice m
dfInputHidden view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = fieldInputText ref view
    return $ makeElement "input" [] $ addAttrs attrs
        [("type", "hidden"), ("id", ref'), ("name", ref'), ("value", value)]


--------------------------------------------------------------------------------
-- | Generate a select button (also known as a combo box). Example:
--
-- > <dfInputSelect ref="user.sex" />
dfInputSelect :: Monad m => View Text -> Splice m
dfInputSelect view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'     = absoluteRef ref view
        choices  = fieldInputChoice ref view
        children = map makeOption choices
        value i  = ref' `mappend` "." `mappend` i

        makeOption (i, c, sel) = X.Element "option"
            (attr sel ("selected", "selected") [("value", value i)])
            [X.TextNode c]

    return $ makeElement "select" children $ addAttrs attrs
        [("id", ref'), ("name", ref')]


--------------------------------------------------------------------------------
-- | Generate a number of radio buttons. Example:
--
-- > <dfInputRadio ref="user.sex" />
dfInputRadio :: Monad m => View Text -> Splice m
dfInputRadio view = do
    (ref, attrs) <- getRefAttributes Nothing

    let ref'     = absoluteRef ref view
        choices  = fieldInputChoice ref view
        children = concatMap makeOption choices
        value i  = ref' `mappend` "." `mappend` i

        makeOption (i, c, sel) =
            [ X.Element "input"
                (attr sel ("checked", "checked") $ addAttrs attrs
                    [ ("type", "radio"), ("value", value i)
                    , ("id", value i), ("name", ref')
                    ]) []
            , X.Element "label" [("for", value i)] [X.TextNode c]
            ]

    return children


--------------------------------------------------------------------------------
-- | Generate a checkbox. Example:
--
-- > <dfInputCheckbox ref="user.married" />
dfInputCheckbox :: Monad m => View Text -> Splice m
dfInputCheckbox view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = fieldInputBool ref view
    return $ makeElement "input" [] $ addAttrs attrs $
        attr value ("checked", "checked") $
        [("type", "checkbox"), ("id", ref'), ("name", ref')]


--------------------------------------------------------------------------------
-- | Generate a file upload element. Example:
--
-- > <dfInputFile ref="user.avatar" />
dfInputFile :: Monad m => View Text -> Splice m
dfInputFile view = do
    (ref, attrs) <- getRefAttributes Nothing
    let ref'  = absoluteRef ref view
        value = maybe "" T.pack $ fieldInputFile ref view
    return $ makeElement "input" [] $ addAttrs attrs
        [("type", "file"), ("id", ref'), ("name", ref'), ("value", value)]


--------------------------------------------------------------------------------
-- | Generate a submit button. Example:
--
-- > <dfInputSubmit />
dfInputSubmit :: Monad m => View v -> Splice m
dfInputSubmit _ = do
    (_, attrs) <- getRefAttributes Nothing
    return $ makeElement "input" [] $ addAttrs attrs [("type", "submit")]


--------------------------------------------------------------------------------
-- | Generate a label for a field. Example:
--
-- > <dfLabel ref="user.married">Married: </dfLabel>
-- > <dfInputCheckbox ref="user.married" />
dfLabel :: Monad m => View v -> Splice m
dfLabel view = do
    (ref, attrs) <- getRefAttributes Nothing
    content      <- getContent
    let ref' = absoluteRef ref view
    return $ makeElement "label" content $ addAttrs attrs [("for", ref')]


--------------------------------------------------------------------------------
-- | Generate a form tag with the @method@ attribute set to @POST@ and
-- the @enctype@ set to the right value (depending on the form).
-- Custom @method@ or @enctype@ attributes would override this
-- behavior. Example:
--
-- > <dfForm action="/users/new">
-- >     <dfInputText ... />
-- >     ...
-- >     <dfInputSubmit />
-- > </dfForm>
dfForm :: Monad m => View v -> Splice m
dfForm view = do
    (_, attrs) <- getRefAttributes Nothing
    content    <- getContent
    return $ makeElement "form" content $ addAttrs attrs
        [ ("method", "POST")
        , ("enctype", T.pack (show $ viewEncType view))
        ]


--------------------------------------------------------------------------------
errorList :: [Text] -> [(Text, Text)] -> [X.Node]
errorList []   _     = []
errorList errs attrs = [X.Element "ul" attrs $ map makeError errs]
  where
    makeError e = X.Element "li" [] [X.TextNode e]


--------------------------------------------------------------------------------
-- | Display the list of errors for a certain field. Example:
--
-- > <dfErrorList ref="user.name" />
-- > <dfInputText ref="user.name" />
dfErrorList :: Monad m => View Text -> Splice m
dfErrorList view = do
    (ref, attrs) <- getRefAttributes Nothing
    return $ errorList (errors ref view) attrs


--------------------------------------------------------------------------------
-- | Display the list of errors for a certain form and all forms below it. E.g.,
-- if there is a subform called @\"user\"@:
--
-- > <dfChildErrorList ref="user" />
--
-- Or display /all/ errors for the form:
--
-- > <dfChildErrorList ref="" />
--
-- Which is more conveniently written as:
--
-- > <dfChildErrorList />
dfChildErrorList :: Monad m => View Text -> Splice m
dfChildErrorList view = do
    (ref, attrs) <- getRefAttributes $ Just ""
    return $ errorList (childErrors ref view) attrs


--------------------------------------------------------------------------------
-- | This splice allows reuse of templates by selecting some child of a form
-- tree. While this may sound complicated, it's pretty straightforward and
-- practical. Suppose we have:
--
-- > <dfInputText ref="user.name" />
-- > <dfInputText ref="user.password" />
-- >
-- > <dfInputTextArea ref="comment.body" />
--
-- You may want to abstract the @\"user\"@ parts in some other template so you
-- Don't Repeat Yourself (TM). If you create a template called @\"user-form\"@
-- with the following contents:
--
-- > <dfInputText ref="name" />
-- > <dfInputText ref="password" />
--
-- You will be able to use:
--
-- > <dfSubView ref="user">
-- >     <apply template="user-form" />
-- > </dfSubView>
-- >
-- > <dfInputTextArea ref="comment.body" />
dfSubView :: Monad m => View Text -> Splice m
dfSubView view = do
    (ref, _) <- getRefAttributes Nothing
    content  <- getContent
    let view' = subView ref view
    nodes <- localTS (bindDigestiveSplices view') $ runNodeList content
    return nodes


--------------------------------------------------------------------------------
-- | Render some content only if there are any errors. This is useful for markup
-- purposes.
--
-- > <dfIfChildErrors ref="user">
-- >     Content to be rendered if there are any errors...
-- > </dfIfChildErrors>
--
-- The @ref@ attribute can be omitted if you want to check the entire form.
dfIfChildErrors :: Monad m => View v -> Splice m
dfIfChildErrors view = do
    (ref, _) <- getRefAttributes $ Just ""
    content  <- getContent
    if null (childErrors ref view)
        then return []
        else runNodeList content
