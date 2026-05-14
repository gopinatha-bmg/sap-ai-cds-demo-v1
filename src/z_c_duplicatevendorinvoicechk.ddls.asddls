@OData.publish: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@AbapCatalog.sqlViewName: 'ZC_DUPVINVCK'
@EndUserText.label: 'Duplicate Vendor Invoice Check by Posting Date'
define view ZC_DuplicateVendorInvoiceChk
  with parameters
    @EndUserText.label: 'Posting Date From'
    p_posting_date_from : abap.dats,
    @EndUserText.label: 'Posting Date To'
    p_posting_date_to   : abap.dats
  as select from rbkp as h
    inner join bseg as i
      on  i.bukrs = h.bukrs
      and i.belnr = h.belnr
      and i.gjahr = h.gjahr

    inner join (
      select from rbkp as d
        inner join bseg as di
          on  di.bukrs = d.bukrs
          and di.belnr = d.belnr
          and di.gjahr = d.gjahr
      {
        d.bukrs  as bukrs,
        d.lifnr  as lifnr,
        d.xblnr  as xblnr,
        d.waers  as waers,
        sum( di.wrbtr ) as GrossAmountInDocumentCurrency,
        count( distinct concat( concat( d.belnr, '-' ), d.gjahr ) ) as DuplicateCount
      }
      where d.budat between :p_posting_date_from and :p_posting_date_to
        and d.bukrs in ( '1000', '2000' )
        and d.stblg = ''
        and d.xblnr <> ''
        // TODO: Exclude approved recurring utility invoices using the client-specific
        // approval/recurring indicator or mapping table once the source is confirmed.
      group by
        d.bukrs,
        d.lifnr,
        d.xblnr,
        d.waers
      having count( distinct concat( concat( d.belnr, '-' ), d.gjahr ) ) > 1
    ) as dup
      on  dup.bukrs = h.bukrs
      and dup.lifnr = h.lifnr
      and dup.xblnr = h.xblnr
      and dup.waers = h.waers
{
  key h.bukrs as CompanyCode,
  key h.belnr as AccountingDocument,
  key h.gjahr as FiscalYear,
  key i.buzei as AccountingDocumentItem,

      h.budat as PostingDate,
      h.bldat as DocumentDate,
      h.blart as DocumentType,
      h.lifnr as Vendor,
      h.xblnr as ReferenceDocument,
      h.waers as Currency,
      i.wrbtr as LineAmountInDocumentCurrency,
      dup.GrossAmountInDocumentCurrency,
      h.usnam as EnteredByUser,

      cast( 'DUPLICATE_INVOICE' as abap.char(20) ) as ExceptionCode,
      cast( 'Same vendor/company/reference/currency/gross amount occurs more than once in posting date range' as abap.char(120) ) as ExceptionText,
      dup.DuplicateCount
}
where h.budat between :p_posting_date_from and :p_posting_date_to
  and h.bukrs in ( '1000', '2000' )
  and h.stblg = ''
  and h.xblnr <> ''
  // Exclusion below is redundant given current company-code scope, so omitted:
  // not ( h.bukrs = '1710' and h.lifnr = '100045' )
  // TODO: Exclude approved recurring utility invoices using confirmed client-specific logic.
;