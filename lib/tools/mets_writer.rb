require 'tools/xml_writer'

class METSWriter
  include XmlWriter

  def initialize
    @document       = create_document
    @document.root  = create_node('mets:mets')
    add_namespaces(@document.root, 'mets'   => 'http://www.loc.gov/METS/')
    add_namespaces(@document.root, 'mods'   => 'http://www.loc.gov/mods/v3')
    add_namespaces(@document.root, 'rts'    => 'http://cosimo.stanford.edu/sdr/metsrights/')
    add_namespaces(@document.root, 'mix'    => 'http://www.loc.gov/mix/')
    add_namespaces(@document.root, 'xlink'  => 'http://www.w3.org/1999/xlink')
    add_namespaces(@document.root, 'xsi'    => 'http://www.w3.org/2001/XMLSchema-instance')
    add_attributes(@document.root, 'xsi:schemaLocation' => 'http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd http://www.loc.gov/mods/v3 .http://www.loc.gov/mods/v3/mods-3-1.xsd http://www.loc.gov/mix/ http://www.loc.gov/mix/mix.xsd http://cosimo.stanford.edu/sdr/metsrights/ http://cosimo.stanford.edu/sdr/metsrights.xsd')

    @document.root  << (@header     = create_node('mets:metsHdr'))
    @document.root  << (@dmdsec     = create_node('mets:dmdSec'))
    @document.root  << (@amdsec     = create_node('mets:amdSec'))
    @document.root  << (@filesec    = create_node('mets:fileSec'))
    @filesec        << (@archives   = create_node('mets:fileGrp', :attributes => {'USE' => 'archive'}))
    @filesec        << (@thumbnails = create_node('mets:fileGrp', :attributes => {'USE' => 'thumbnail'}))
    @filesec        << (@indexes    = create_node('mets:fileGrp', :attributes => {'USE' => 'index'}))
    @filesec        << (@references = create_node('mets:fileGrp', :attributes => {'USE' => 'reference'}))
    @filesec        << (@ref_images = create_node('mets:fileGrp', :attributes => {'USE' => 'reference image'}))
    @filesec        << (@ref_video  = create_node('mets:fileGrp', :attributes => {'USE' => 'reference video'}))
    @filesec        << (@ref_audio  = create_node('mets:fileGrp', :attributes => {'USE' => 'reference audio'}))
    @filesec        << (@ref_text   = create_node('mets:fileGrp', :attributes => {'USE' => 'reference text'}))
    @document.root  << (@s_map      = create_node('mets:structMap'))
    @document.root  << (@slink      = create_node('mets:structLink'))
    @document.root  << (@behavior   = create_node('mets:behaviorSec'))
  end

  def add_file(file_name, label, usage_type, entity_type = nil, extra_options = {})
    return nil unless object.file_info
    file_group = @references
    case object.usage_type
    when /ORIGINAL$/i
      file_group = @archives
    when 'ARCHIVE'
      file_group = 


  def write(file_name)
    @document.save file_name, :indent => true
  end

end
