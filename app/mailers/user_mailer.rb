class UserMailer < ActionMailer::Base
  layout 'mail'

  def interests(user)
  	@user = user
   	mail( from: "GitHug <notify@githug.com>" ,
          to: "#{@user.name} <#{@user.email}>",
   				subject: "",
   				layout: "mail")
  end
end
